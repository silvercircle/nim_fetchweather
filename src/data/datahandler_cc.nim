import datahandler

type DataHandler_CC* = ref object of DataHandler

method populateSnapshot*(this: DataHandler_CC): void =
  echo "populate in DataHandler_CC"
