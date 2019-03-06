# 统计各个状态的连接数
ss -an | awk '{ array[$2]++ } END { for (k in array) print k, array[k] }' | sort -rnk2

# 查看time-wait状态的连接
ss -an state time-wait
