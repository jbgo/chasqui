#!/bin/sh

if [ -z "$REDIS_URL" ]; then
  REDIS_URL=$(echo $REDIS_PORT | sed s/tcp/redis/)
fi

chasqui -r $REDIS_URL
