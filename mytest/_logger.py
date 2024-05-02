import logging

def get_logger(filename):

    logging.basicConfig(filename=f'{filename}', level=logging.DEBUG, encoding='utf-8', format='%(asctime)s (%(levelname)s) : %(message)s')
    logger = logging.getLogger(__name__)

    return logger