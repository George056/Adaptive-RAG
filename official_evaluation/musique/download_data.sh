#!/bin/bash

set -e
set -x

pip install gdown

ZIP_NAME="musique_v1.0.zip"

# URL: https://drive.google.com/file/d/1tGdADlNjWFaHLeZZGShh2IRcpO6Lv24h/view?usp=sharing
gdown --id 1tGdADlNjWFaHLeZZGShh2IRcpO6Lv24h --output $ZIP_NAME
unzip $(basename $ZIP_NAME)
rm $ZIP_NAME

rm -rf __MACOSX
