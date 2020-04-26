#!/bin/bash

TC=/sbin/tc
IF=eth0				
ARG=$1 
RATE=8000									#100k - Nmbit: 100kbit - 20000kbit
BUFFERRATE=0.01								#0.01
BURST=`echo "$RATE * $BUFFERRATE" | bc` 
DELAY=0										#0 - 200ms: 0 - 200
LOSS=0										#0 - 20%: 0 - 0.2
DUPLICATE=0									#0 - 0.1%: 0 - 0.001
REORDER=0									#0 - 5%: 0 - 0.05
count=0
num=0
rnetem=0

set_tc_tbf() {
	#$TC qdisc add dev $IF root handle 1: tbf rate 4mbit burst 30kbit limit 30kbit
	if	[ $1 == "add" ]
	then
		echo "----------------------------------------------------$TC qdisc add dev $IF root handle 1: tbf $2"
		$TC qdisc add dev $IF root handle 1: tbf $2
	elif [ $1 == "change" ]
	then
		echo "----------------------------------------------------$TC qdisc change dev $IF root handle 1: tbf $2"
		$TC qdisc change dev $IF root handle 1: tbf $2
	fi	  
}

set_tc_netem() {
	#$TC qdisc add dev $IF parent 1: handle 2: netem loss 5%
	if [ $1 == "add" ]
	then
		echo "----------------------------------------------------$TC qdisc add dev $IF parent 1: handle 2: netem $2"
		$TC qdisc add dev $IF parent 1: handle 2: netem $2
	elif [ $1 == "change" ]
	then
		echo "----------------------------------------------------$TC qdisc change dev $IF parent 1: handle 2: netem $2"
		$TC qdisc change dev $IF parent 1: handle 2: netem $2
	fi
}

loger() {
	TIME=`date +%F' '%R:%S`
	echo "$count: $TIME ${IF} rate=${RATE}kbit burst=${BURST}kbit delay=${DELAY}ms loss=${LOSS}% duplicate=${DUPLICATE}% reorder=${REORDER}%" >> ${IF}-slimit.log
}

rdata() {
	min=$1  
	max=`echo "$2-$min" | bc`
	num=`echo "$RANDOM%$max+$min" | bc` 
	#echo $num
}

start_set() {
	set_tc_tbf add "rate 0kbit burst 0kbit limit 0kbit"
	set_tc_netem add "loss 0% delay 0ms duplicate 0% reorder 0%"
}

start() {
	loger
	set_tc_tbf add "rate ${RATE}kbit burst ${BURST}kbit limit ${BURST}kbit"
	set_tc_netem add "loss $LOSS% delay ${DELAY}ms duplicate $DUPLICATE% reorder $REORDER%"
	show
	while (($count < 20))
	do
		let count=$count+1
		sleep 1
		loger 
		if [ $(($count % 10)) == 0 ]
		then
			#echo $count		# debug
			#rdata 100 20000	# kbit, 100 - 20000		
			#rdata 0 200		# ms, 0 - 200
			#rdata 0 20			# %, 0 - 20
			#rdata 0 100		# %, 0 - 0.001, 0 - 100 / 100000
			#rdata 0 50			# %, 0 - 0.05, 0 - 50 / 1000
			#rdata 0 3
			#echo "----------------------"
			rdata 100 20000
			RATE=$num
			BURST=`echo "$RATE * $BUFFERRATE" | bc` 
			rdata 0 20
			LOSS=$num
			rdata 0 3
			set_tc_tbf change "rate ${RATE}kbit burst ${BURST}kbit limit ${BURST}kbit"
			#set_tc_netem change "loss $LOSS%"
			set_tc_netem add "loss $LOSS% delay ${DELAY}ms duplicate $DUPLICATE% reorder $REORDER%"
			if [ $num -eq 0 ]
			then
				rdata 0 200
				DELAY=$num
				#set_tc_netem change "delay ${DELAY}ms"
				set_tc_netem change "loss $LOSS% delay ${DELAY}ms duplicate $DUPLICATE% reorder $REORDER%"
			elif [ $num -eq 1 ]
			then
				rdata 0 100
				DUPLICATE=`echo "scale=5;$num/100000"| bc`
				#set_tc_netem change "duplicate $DUPLICATE%"
				set_tc_netem change "loss $LOSS% delay ${DELAY}ms duplicate $DUPLICATE% reorder $REORDER%"
			elif [ $num -eq 2 ]
			then
				rdata 0 50
				REORDER=`echo "scale=3;$num/1000" | bc`
				#set_tc_netem change "delay 1ms reorder $REORDER%"
				set_tc_netem change "loss $LOSS% delay 1ms duplicate $DUPLICATE% reorder $REORDER%"
			fi
			show
		fi
	done
	stop
}

stop() {
	$TC qdisc del dev $IF root
}

show() {
	$TC qdisc show
}

#single set
srate() {
	echo "rate $1 $2"
	RATE=$1
	ST=$2
	stop
	show
	set_tc_tbf add "rate ${RATE}kbit burst ${BURST}kbit limit ${BURST}kbit"
	show
	loger
	sleep $ST
	loger
	stop
	show
	loger
}

sdelay() {
	echo "delay $1 $2"
	DELAY=$1
	ST=$2
	stop
	show
	set_tc_tbf add "rate ${RATE}kbit burst ${BURST}kbit limit ${BURST}kbit"
	set_tc_netem add "loss $LOSS% delay ${DELAY}ms duplicate $DUPLICATE% reorder $REORDER%"
	show
	loger
	sleep $ST
	loger
	stop
	show
	loger
}

sloss() {
	echo "loss $1 $2"
	LOSS=$1
	ST=$2
	stop
	show
	set_tc_tbf add "rate ${RATE}kbit burst ${BURST}kbit limit ${BURST}kbit"
	set_tc_netem add "loss $LOSS% delay ${DELAY}ms duplicate $DUPLICATE% reorder $REORDER%"
	show
	loger
	sleep $ST
	loger
	stop
	show
	loger
}

sduplicate() {
	echo "duplicate $1 $2"
	DUPLICATE=$1
	ST=$2
	stop
	show
	set_tc_tbf add "rate ${RATE}kbit burst ${BURST}kbit limit ${BURST}kbit"
	set_tc_netem add "loss $LOSS% delay ${DELAY}ms duplicate $DUPLICATE% reorder $REORDER%"
	show
	loger
	sleep $ST
	loger
	stop
	show
	loger
}

sreorder() {
	echo "reorder $1 $2"
	REORDER=$1
	ST=$2
	stop
	show
	set_tc_tbf add "rate ${RATE}kbit burst ${BURST}kbit limit ${BURST}kbit"
	set_tc_netem add "loss $LOSS% delay ${DELAY}ms duplicate $DUPLICATE% reorder $REORDER%"
	show
	loger
	sleep $ST
	loger
	stop
	show
	loger
}

case $ARG in
	start)
		stop
		start
		;;
	stop)
		stop
		show
		;;
	show)
		show
		;;
	set)
		start_set
		;;
	r)
		srate $2 $3
		;;
	de)
		sdelay $2 $3
		;;
	l)
		sloss $2 $3
		;;
	du)
		sduplicate $2 $3
		;;
	re)
		sreorder $2 $3
		;;
	*)
		echo "USAGE:	xx.sh [option: start|stop|show|set]
	xx.sh [option: r|de|l|du|re] [parameter]
	1) xx.sh start
	2) xx.sh stop
	3) xx.sh show
	4) xx.sh set
	5) xx.sh r rate(kbit) sleeptime(seconds)
		xx.sh r 4000 3
	6) xx.sh de deelay(ms) sleeptime(seconds)
		xx.sh de 40 3
	7) xx.sh l loss(%) sleeptime(seconds)
		xx.sh l 10 3
	8) xx.sh du duplicate(%) sleeptime(seconds)
		xx.sh du 2 3
	9) xx.sh re reorder(%) sleeptime(seconds)
		xx.sh re 1 3"
esac
