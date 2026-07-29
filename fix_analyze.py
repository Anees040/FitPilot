import os
import re
import subprocess

def fix_errors():
    result = subprocess.run(['flutter', 'analyze'], capture_output=True, text=True, shell=True)
    lines = result.stdout.splitlines()
    
    for line in lines:
        if 'invalid_constant' in line or 'const_eval_method_invocation' in line:
            match = re.search(r' - (lib\\[^:]+):(\d+):\d+ - ', line)
            if match:
                file = match.group(1).replace('\\', '/')
                lineno = int(match.group(2))
                
                with open(file, 'r', encoding='utf-8') as f:
                    content_lines = f.readlines()
                
                if lineno - 1 < len(content_lines):
                    # search upwards for const
                    for i in range(lineno - 1, max(-1, lineno - 15), -1):
                        if 'const ' in content_lines[i]:
                            content_lines[i] = re.sub(r'\bconst\s+', '', content_lines[i], count=1)
                            break
                            
                    with open(file, 'w', encoding='utf-8') as f:
                        f.writelines(content_lines)
                        
        if 'unused_import' in line and 'app_theme.dart' in line:
            match = re.search(r' - (lib\\[^:]+):(\d+):\d+ - ', line)
            if match:
                file = match.group(1).replace('\\', '/')
                lineno = int(match.group(2))
                with open(file, 'r', encoding='utf-8') as f:
                    content_lines = f.readlines()
                if lineno - 1 < len(content_lines):
                    content_lines[lineno - 1] = ''
                with open(file, 'w', encoding='utf-8') as f:
                    f.writelines(content_lines)

for i in range(6):
    print("Fixing pass", i+1)
    fix_errors()
    
result = subprocess.run(['flutter', 'analyze'], capture_output=True, text=True)
print("Final analysis:")
print(result.stdout)
