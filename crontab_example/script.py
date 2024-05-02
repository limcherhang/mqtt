import datetime
import sys
from pathlib import Path
my_path = str(Path.cwd())
sys.path.append(my_path)
print(sys.path)

with open(my_path+'/output.txt', 'a') as f:
    f.write(f"Insert into output.txt: {datetime.datetime.now().time()}\n")
