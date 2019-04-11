module Marlowe.Contracts where

depositIncentive :: String
depositIncentive = "Commit 1 1 1 \n  (Constant 100) 10 200 \n  (Commit 2 2 2 \n     (Constant 20) 20 200 \n     (When \n        (ChoseSomething (1, 1)) 100 \n        (Both \n           (Pay 3 1 1 \n              (Constant 100) 200 Null Null) \n           (Pay 4 2 2 \n              (Constant 20) 200 Null Null)) \n        (Both \n           (Pay 5 1 1 \n              (Constant 100) 200 Null Null) \n           (Pay 6 2 1 \n              (Constant 20) 200 Null Null))) \n     (Pay 7 1 1 \n        (Constant 100) 200 Null Null)) Null" 

crowdFunding :: String
crowdFunding = "Both \n  (Both \n     (Both \n        (When \n           (AndObs \n              (ChoseSomething (1, 1)) \n              (ValueGE \n                 (ValueFromChoice (1, 1) \n                    (Constant 0)) \n                 (Constant 1))) 10 \n           (Commit 1 1 1 \n              (ValueFromChoice (1, 1) \n                 (Constant 0)) 10 20 Null Null) Null) \n        (When \n           (AndObs \n              (ChoseSomething (1, 2)) \n              (ValueGE \n                 (ValueFromChoice (1, 2) \n                    (Constant 0)) \n                 (Constant 1))) 10 \n           (Commit 2 2 2 \n              (ValueFromChoice (1, 2) \n                 (Constant 0)) 10 20 Null Null) Null)) \n     (Both \n        (When \n           (AndObs \n              (ChoseSomething (1, 3)) \n              (ValueGE \n                 (ValueFromChoice (1, 3) \n                    (Constant 0)) \n                 (Constant 1))) 10 \n           (Commit 3 3 3 \n              (ValueFromChoice (1, 3) \n                 (Constant 0)) 10 20 Null Null) Null) \n        (When \n           (AndObs \n              (ChoseSomething (1, 4)) \n              (ValueGE \n                 (ValueFromChoice (1, 4) \n                    (Constant 0)) \n                 (Constant 1))) 10 \n           (Commit 4 4 4 \n              (ValueFromChoice (1, 4) \n                 (Constant 0)) 10 20 Null Null) Null))) \n  (When FalseObs 10 Null \n     (Choice \n        (ValueGE \n           (AddValue \n              (AddValue \n                 (Committed 1) \n                 (Committed 2)) \n              (AddValue \n                 (Committed 3) \n                 (Committed 4))) \n           (Constant 1000)) \n        (Both \n           (Both \n              (Pay 5 1 5 \n                 (Committed 1) 20 Null Null) \n              (Pay 6 2 5 \n                 (Committed 2) 20 Null Null)) \n           (Both \n              (Pay 7 3 5 \n                 (Committed 3) 20 Null Null) \n              (Pay 8 4 5 \n                 (Committed 4) 20 Null Null))) Null))"

escrow :: String
escrow = "Commit 1 1 1 \n  (Constant 450) 10 100 \n  (When \n     (OrObs \n        (OrObs \n           (AndObs \n              (ChoseThis (1, 1) 0) \n              (OrObs \n                 (ChoseThis (1, 2) 0) \n                 (ChoseThis (1, 3) 0))) \n           (AndObs \n              (ChoseThis (1, 2) 0) \n              (ChoseThis (1, 3) 0))) \n        (OrObs \n           (AndObs \n              (ChoseThis (1, 1) 1) \n              (OrObs \n                 (ChoseThis (1, 2) 1) \n                 (ChoseThis (1, 3) 1))) \n           (AndObs \n              (ChoseThis (1, 2) 1) \n              (ChoseThis (1, 3) 1)))) 90 \n     (Choice \n        (OrObs \n           (AndObs \n              (ChoseThis (1, 1) 1) \n              (OrObs \n                 (ChoseThis (1, 2) 1) \n                 (ChoseThis (1, 3) 1))) \n           (AndObs \n              (ChoseThis (1, 2) 1) \n              (ChoseThis (1, 3) 1))) \n        (Pay 2 1 2 \n           (Committed 1) 100 Null Null) \n        (Pay 3 1 1 \n           (Committed 1) 100 Null Null)) \n     (Pay 4 1 1 \n        (Committed 1) 100 Null Null)) Null" 


