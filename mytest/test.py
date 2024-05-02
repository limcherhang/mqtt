import threading

# 創建一個 Lock 對象
lock = threading.Lock()

# 共享資源
shared_resource = 0

# 執行緒函數
def modify_resource():
    global shared_resource
    with lock:  # 使用 with 語句來獲取和釋放鎖
        shared_resource += 1

# 創建多個執行緒
threads = []
for _ in range(5):
    thread = threading.Thread(target=modify_resource)
    threads.append(thread)
    thread.start()
    print("current threads, ", threads)

# 等待所有執行緒完成
for thread in threads:
    thread.join()

print("Shared resource value:", shared_resource)