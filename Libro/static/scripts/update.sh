ROOT=$(dirname $(readlink -f $0))/../..
ZIP_FILE=static.zip
ZIP_URL=https://prolibreros.gitlab.io/docs/tutorial-ssp/$ZIP_FILE

cd $ROOT
echo "[INFO] Downloading $ZIP_URL"
curl -LO $ZIP_URL
if test -f "$ZIP_FILE"; then
  echo "[INFO] Updating project"
  rm -rf static
  unzip -qq static.zip
  rm $ZIP_FILE
  echo "[WARNING] You might have to modify the metadata"
  echo "[INFO] Ready!"
fi
