import inspect
import logging

LOG_FORMAT = "%(asctime)s - %(threadName)s %(message)s"
DATE_FORMAT = "%m-%d-%Y %H:%M:%S"

def init():
	logging.basicConfig(level=logging.NOTSET,format=LOG_FORMAT, datefmt=DATE_FORMAT)
	logging.Formatter

def d(str):
	logging.debug(str)

def i(str):
	logging.info(str)

def w(str):
	logging.warning(str)

def e(str):
	logging.error(str)

def c(str):
	logging.critical(str)

