import datahandler

type DataHandler_OWM* = ref object of DataHandler

method populateSnapshot*(this: DataHandler_OWM): void =
  echo "populate in DataHandler_OWM"
