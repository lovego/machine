# 统计各个状态的连接数
ss -n | awk '{ array[$2]++ } END { for (k in array) print k, array[k] }'
