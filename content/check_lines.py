import sys

# 读取文件
with open(r'C:\Users\chenjiageng\Desktop\sunliao\flutter-app\lib\utils\permission_manager.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第360-370行
print("=== permission_manager.dart 第360-370行 ===")
for i in range(359, min(370, len(lines))):
    print(f"{i+1}: {lines[i]}", end='')

print("\n\n=== profile_tab.dart 第430-440行 ===")
with open(r'C:\Users\chenjiageng\Desktop\sunliao\flutter-app\lib\widgets\profile_tab.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i in range(429, min(440, len(lines))):
    print(f"{i+1}: {lines[i]}", end='')

print(f"\n\n总行数: permission_manager.dart = {len(lines)}")

