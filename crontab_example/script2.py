import datetime
import sys
from pathlib import Path
my_path = str(Path.cwd())
sys.path.append(my_path)
print(sys.path)

with open(my_path+'/output_reboot.txt', 'a') as f:
    f.write(f"Insert into output_reboot.txt: {datetime.datetime.now().time()}\n")
