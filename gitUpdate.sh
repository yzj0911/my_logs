#!/bin/bash

hugo 
hugo -d docs
git add ./
v_date=$(date -d"-1 days" +"%Y%m%d")
git commit -m "${v_date}"
git push
