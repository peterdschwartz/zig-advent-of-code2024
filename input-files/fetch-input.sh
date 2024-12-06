#!/bin/bash -e
set -x
DAY=$1
url="https://adventofcode.com/2024/day/$DAY/input"
if [ -e aoc-input$DAY.txt ]; then
	echo "Input for Day $DAY already downloaded!"
else
	echo "Fetching AoC Day $DAY input:"
	curl -b session=$AOC $url > aoc-input$DAY.txt
fi
