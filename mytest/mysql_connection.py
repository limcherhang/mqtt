import yaml
import pymysql
import logging
from typing import Union

logger = logging.getLogger(__name__)

class MySQLConn:
    def __init__(self, db_env: Union[int, str], autocommit: bool=True, dict_mode: bool=True) -> None:
        self.db_env = db_env
        self.autocommit = autocommit
        self.dict_mode = dict_mode

    def setup(self,):
        db_info = yaml.load(open('dbconfig.yaml'), yaml.loader.SafeLoader)
        db = f"mysql_{self.db_env}"
        db_cfg = db_info[db]
        logger.info(f"our db_config: {db_cfg}")
        if self.dict_mode:
            self.connection = pymysql.connect(
                host=db_cfg['host'],
                port=db_cfg['port'],
                user=db_cfg['user'],
                password=db_cfg['password'],
                autocommit=self.autocommit,
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )
        else:
            self.connection = pymysql.connect(
                host=db_cfg['host'],
                port=db_cfg['port'],
                user=db_cfg['user'],
                password=db_cfg['password'],
                autocommit=self.autocommit,
                charset='utf8mb4',
            )

        self.cursor = self.connection.cursor()
        
        return self.cursor
    
    def close(self,):
        self.cursor.close()
        self.connection.close()