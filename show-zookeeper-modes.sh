#!/bin/bash
echo Zookeeper Modes: && \
echo stat | nc localhost 2181 | grep Mode | sed 's/.*/Zoo1 -> &/' && \
echo stat | nc localhost 2182 | grep Mode | sed 's/.*/Zoo2 -> &/'&& \
echo stat | nc localhost 2183 | grep Mode | sed 's/.*/Zoo3 -> &/'