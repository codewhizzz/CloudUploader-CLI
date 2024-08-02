#!/bin/bash

# Load environment variables from a .env file if available
if [ -f .env ]; then
    source .env
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Azure CLI not found. Please install it and configure your credentials."
    exit 1
fi

# Check if pv is installed (though it's no longer needed for upload)
if ! command -v pv &> /dev/null; then
    echo "pv command not found. Please install it if you want to see progress for other operations."
fi

# Verify that necessary environment variables are set
if [ -z "$AZURE_STORAGE_ACCOUNT" ] || [ -z "$AZURE_STORAGE_KEY" ]; then
    echo "Error: Azure storage account or key is not set."
    echo "Please set the AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_KEY environment variables."
    exit 1
fi

# Parse Command-Line Arguments
FILE_PATH=$1
CONTAINER_NAME=$2
BLOB_NAME=$3

# Validate the file path is provided
if [ -z "$FILE_PATH" ]; then
  echo "Error: No file path provided."
  exit 1
fi

# Validate the file path exists
if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File '$FILE_PATH' not found. Please check the file path."
  exit 1
fi

# Set default container name if not provided
if [ -z "$CONTAINER_NAME" ]; then
  CONTAINER_NAME="mycontainer"  # Default container name
fi

# Set default blob name if not provided
if [ -z "$BLOB_NAME" ]; then
  BLOB_NAME=$(basename "$FILE_PATH")  # Default blob name based on the file name
fi

# Check if the blob already exists
EXISTING_BLOB=$(az storage blob exists --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_KEY --container-name $CONTAINER_NAME --name $BLOB_NAME --query "exists" --output tsv)

if [ "$EXISTING_BLOB" == "true" ]; then
  echo "File already exists in the cloud. Overwrite (o), skip (s), rename (r)?"
  read choice
  case $choice in
    o) echo "Overwriting existing blob...";;
    s) echo "Upload skipped."; exit 0;;
    r) 
      NEW_NAME="${BLOB_NAME%.*}_new.${BLOB_NAME##*.}"
      BLOB_NAME=$NEW_NAME
      ;;
    *) echo "Invalid choice. Exiting."; exit 1;;
  esac
fi

# Upload the file without pv
az storage blob upload --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_KEY --container-name $CONTAINER_NAME --name $BLOB_NAME --file "$FILE_PATH"

# Check if the upload was successful
if [ $? -eq 0 ]; then
  echo "File uploaded successfully to https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$CONTAINER_NAME/$BLOB_NAME"
  SHARE_URL="https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$CONTAINER_NAME/$BLOB_NAME"
  echo "Shareable URL: $SHARE_URL"
else
  echo "Error: Upload failed. Please check your connection and credentials."
  exit 1
fi

