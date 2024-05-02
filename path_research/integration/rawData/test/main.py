import sys
from pathlib import Path
sys.path.append(str(Path.cwd()))
print(sys.path)
print()

from connection import mysql_connection

# 使用 mysql_connection 中的函數
mysql_connection.connect_mysql_db()