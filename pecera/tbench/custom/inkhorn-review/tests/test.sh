#!/bin/bash
mkdir -p /logs/verifier
echo 0 > /logs/verifier/reward.txt
tar -C /app --exclude=node_modules -czf /logs/verifier/game-final.tgz game 2>/dev/null
mkdir -p /logs/verifier/shots && cp /tmp/*.png /logs/verifier/shots/ 2>/dev/null
cd /app/game 2>/dev/null || cd /app
node /tests/grader.js 2>&1 | tee /logs/verifier/grader.txt
exit 0
