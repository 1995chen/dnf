#! /bin/bash

# 请注意, 如果修改该脚本请确保输出结果为纯IP
echo $(curl -s https://v4.ident.me 2>/dev/null || true)
