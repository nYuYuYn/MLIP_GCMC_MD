#!/bin/bash
mlip select_add curr.almtp train.cfg test_12_cfg/train.cfg new_cfg12.cfg
cat new_cfg12.cfg >> train.cfg
mlip select_add curr.almtp train.cfg test_12_cfg/train.cfg new_cfg16.cfg
cat new_cfg16.cfg >> train.cfg
python clean.py
./train.sh