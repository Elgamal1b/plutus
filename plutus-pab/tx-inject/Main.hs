{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE NamedFieldPuns     #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE OverloadedStrings  #-}
{-# LANGUAGE StrictData         #-}

module Main where

import           Control.Concurrent             (ThreadId, forkIO, myThreadId, throwTo)
import           Control.Concurrent.STM         (atomically)
import           Control.Concurrent.STM.TBQueue (TBQueue, newTBQueueIO, readTBQueue, writeTBQueue)
import           Control.Concurrent.STM.TVar    (TVar, modifyTVar', newTVarIO, readTVar)
import           Control.Exception              (AsyncException (..))
import           Control.Lens                   hiding (ix)
import           Control.Monad                  (forever)
import           Control.Monad.IO.Class         (liftIO)
import           Control.RateLimit              (rateLimitExecution)
import qualified Data.Map                       as Map
import           Data.Text                      (Text)
import qualified Data.Text                      as T
import qualified Data.Text.IO                   as T
import           Data.Time.Units                (Microsecond, fromMicroseconds)
import           Data.Yaml                      (decodeFileThrow)
import           GHC.Generics                   (Generic)
import           Network.HTTP.Client            (ManagerSettings (..), newManager, setRequestIgnoreStatus)
import           Network.HTTP.Conduit           (tlsManagerSettings)
import           Options.Applicative            (Parser, ParserInfo, auto, execParser, fullDesc, help, helper, info,
                                                 long, metavar, option, progDesc, short, showDefault, strOption, value,
                                                 (<**>))
import           Servant.Client                 (ClientEnv (..), mkClientEnv, runClientM)
import           System.Clock                   (Clock (..), TimeSpec (..), getTime)
import           System.Random.MWC              (GenIO, createSystemRandom)
import           System.Signal                  (installHandler, sigINT)
import           Text.Pretty.Simple             (pPrint)

import           Cardano.Node.Client            (addTx)
import           Cardano.Node.RandomTx          (generateTx)
import           Cardano.Node.Server            (MockServerConfig (..))
import           Language.Plutus.Contract.Trace (defaultDist)
import           Ledger.Index                   (UtxoIndex (..), insertBlock)
import           Ledger.Tx                      (Tx (..))
import           Plutus.PAB.Types               (Config (..))
import           Wallet.Emulator                (chainState, txPool, walletPubKey)
import           Wallet.Emulator.MultiAgent     (emulatorStateInitialDist)

data Stats = Stats
  { stStartTime :: TimeSpec
  , stCount     :: Integer
  , stUtxoSize  :: Int
  , stEndTime   :: TimeSpec
  } deriving (Show, Generic)

data AppEnv = AppEnv
  { clientEnv :: ClientEnv
  , txQueue   :: TBQueue Tx
  , stats     :: TVar Stats
  , utxoIndex :: UtxoIndex
  }

initialUtxoIndex :: UtxoIndex
initialUtxoIndex =
  let initialTxs =
        view (chainState . txPool)$
        emulatorStateInitialDist $
        Map.mapKeys walletPubKey defaultDist
  in insertBlock initialTxs (UtxoIndex Map.empty)

runProducer :: AppEnv -> IO ThreadId
runProducer AppEnv{txQueue, stats, utxoIndex} = do
  rng <- createSystemRandom
  forkIO $ producer rng utxoIndex
  where
    producer :: GenIO -> UtxoIndex -> IO ()
    producer rng utxo = do
      tx <- generateTx rng utxo
      let utxo' = insertBlock [tx] utxo
      atomically $ do
        writeTBQueue txQueue tx
        modifyTVar' stats $ \s -> s { stUtxoSize = Map.size $ getIndex utxo' }
      producer rng utxo'

consumer :: AppEnv -> IO ()
consumer AppEnv {clientEnv, txQueue, stats} = do
  tx <- atomically $ readTBQueue txQueue
  atomically $ modifyTVar' stats incrementCount
  _ <- runClientM (addTx tx) clientEnv
  pure ()
  where
    incrementCount :: Stats -> Stats
    incrementCount s = s { stCount = stCount s + 1 }

completeStats :: ThreadId -> TVar Stats -> IO ()
completeStats parent stats = do
  endTime <- getTime Monotonic
  updatedStats <-
    atomically $ do
      modifyTVar' stats $ \s -> s { stEndTime = endTime }
      readTVar stats
  putStrLn ""
  pPrint updatedStats
  T.putStrLn $ showStats updatedStats
  throwTo parent UserInterrupt

showStats :: Stats -> Text
showStats Stats {stStartTime, stCount, stEndTime} =
  let dt = sec stEndTime - sec stStartTime
      fr = stCount `div` toInteger dt
  in  "TPS: " <> (T.pack $ show fr)

-- Options

data InjectOptions = InjectOptions
  { ioRate         :: Integer
  , ioServerConfig :: String
  } deriving (Show, Generic)

cmdOptions :: Parser InjectOptions
cmdOptions = InjectOptions
  <$> option auto
    (  long "rate"
    <> short 'r'
    <> metavar "RATE"
    <> value 0
    <> showDefault
    <> help "Produce RATE transactions per second." )
  <*> strOption
    (  long "config"
    <> short 'c'
    <> metavar "CONFIG"
    <> help "Read configuration from the CONFIG file" )

prgHelp :: ParserInfo InjectOptions
prgHelp = info (cmdOptions <**> helper)
        ( fullDesc
       <> progDesc "Inject transactions into the SCB at specified RATEs." )

rateLimitedConsumer
  :: InjectOptions
  -> IO (AppEnv -> IO ())
rateLimitedConsumer InjectOptions{ioRate} = do
  let rate :: Microsecond
        = fromMicroseconds $
            if ioRate == 0
            then ioRate
            else 1_000_000 `div` ioRate
  if  rate == 0
  then pure consumer
  else do
    rateLimitExecution rate consumer

initializeStats :: IO (TVar Stats)
initializeStats = do
  sTime <- getTime Monotonic
  newTVarIO Stats { stStartTime = sTime
                  , stCount = 0
                  , stUtxoSize = 0
                  , stEndTime = sTime
                  }

initializeInterruptHandler :: TVar Stats -> IO ()
initializeInterruptHandler stats = do
  tid <- myThreadId
  installHandler sigINT (const $ completeStats tid stats)

initializeClientEnv :: Config -> IO ClientEnv
initializeClientEnv cfg =
  mkClientEnv <$> liftIO mkManager
              <*> pure (mscBaseUrl . nodeServerConfig $ cfg)
  where
    mkManager =
      newManager $
      tlsManagerSettings
        { managerModifyRequest = pure . setRequestIgnoreStatus }

main :: IO ()
main = do
  opts <- execParser prgHelp
  pPrint opts
  config <- liftIO $ decodeFileThrow (ioServerConfig opts)
  env    <-
    AppEnv <$> initializeClientEnv config
           <*> newTBQueueIO 1000
           <*> initializeStats
           <*> pure initialUtxoIndex
  initializeInterruptHandler (stats env)
  _   <- runProducer env
  forever =<< rateLimitedConsumer opts <*> pure env
