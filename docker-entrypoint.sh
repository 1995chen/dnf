if [ "`ls -l /var/lib/mysql|wc -l`" > "3" ]; then
  mv /var/lib/mysql_bak/* /var/lib/mysql/
else
  echo "mysql file already exists"
fi

if [ "`ls -A /root/`" = "" ]; then
  mv /root_bak/* /root/
else
  echo "root file already exists"
fi

if [ "`ls -A /root/`" = "" ]; then
  mv /root_bak/* /root/
else
  echo "root file already exists"
fi

mv /home/neople_bak/* /home/neople/
cd /root
./run