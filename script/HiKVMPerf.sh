#!/bin/sh

function usage(){
  echo "Usage: $0 action"
  echo " "
  echo "example: $0 tuning"
  echo "         $0 verify"
  echo "         $0 restore"
  echo " "
  echo "重要：工具仅可在限制场景下使用"
  echo " "
  echo "本工具用于虚拟机自动性能调优，调优和恢复都是重启生效"
  echo "调优项包括：1、关闭透明大页；2、配置512M内存大页；3、虚拟机CPU和内存的NUMA Aware(范围绑核)"
  echo "所有备份文件保存在脚本执行目录下backup文件夹内"
}

# RQ940 ubuntu-18.04
grub=/boot/grub/grub.cfg
# TaiShan 2280 CentOS-7.5
#grub=$grub


function restoreconfig(){
  echo "Tuning failed. Start to restore the original configuration."
  if [ -f "./backup/grub.cfg.bak" ]; then
    /bin/cp -f ./backup/grub.cfg.bak $grub
  fi
  if [ -d "./backup/vmconfig" ]; then
    /bin/cp -rf ./backup/vmconfig/* /etc/libvirt/qemu
  fi
  echo "The configuration has been restored. Please modify as prompted and re-tune."
}

function close_transparent_hugepage(){
  echo "Start to configure transparent hugepage."
  #Close the transparent hugepage
  if [[ -n `cat $grub | grep transparent_hugepage=[a-zA-Z]*\ *` ]]; then
    sed -i 's/transparent_hugepage=[a-zA-Z]*\ */transparent_hugepage=never\ /g' $grub
  else
    sed -i '/linux \/vmlinuz/ s/$/\ transparent_hugepage=never/' $grub
  fi
  echo "Configured."
}

function configure_512M_hugepage(){
  echo "Start to configure 512MB hugepage." 
  #Calculate the appropriate number of hugepages(512MB).
  mem_total_kb=`cat /proc/meminfo | grep MemTotal | tr -cd "[0-9]"`
  mem_avail_mb=$(echo "$mem_total_kb * 0.85 / 1024"|bc)
  numanum=`lscpu | grep "NUMA node(s):" | awk '{print $3}'`
  hugepagenum=$[$mem_avail_mb / 512 / $numanum * $numanum]
  #Check if the hugepage is configured
  if [[ -n `cat $grub | grep default_hugepagesz=[0-9]*[a-zA-Z]*\ *` ]]; then
    sed -i 's/default_hugepagesz=[0-9]*[a-zA-Z]*\ */default_hugepagesz=512M\ /g' $grub
  else
    sed -i '/linux \/vmlinuz/ s/$/\ default_hugepagesz=512M/' $grub
  fi
  if [[ -n `cat $grub | grep \ hugepagesz=[0-9]*[a-zA-Z]*\ *` ]]; then
    sed -i 's/\ hugepagesz=[0-9]*[a-zA-Z]*\ */\ hugepagesz=512M\ /g' $grub
  else
    sed -i '/linux \/vmlinuz/ s/$/\ hugepagesz=512M/' $grub
  fi
  if [[ -n `cat $grub | grep hugepages=[0-9]*\ *` ]]; then
    sed -i 's/hugepages=[0-9]*\ */hugepages='$hugepagenum'\ /g' $grub
  else
    sed -i '/linux \/vmlinuz/ s/$/\ hugepages='$hugepagenum'/' $grub
  fi
  
  for i in `cat ./backup/vmlist.txt`;
  do
    if [[ ! -n `cat /etc/libvirt/qemu/"$i".xml | grep "  <memoryBacking>"` ]]; then    
      sed -i '/currentMemory unit/a\  <memoryBacking>\n    <hugepages/>\n  </memoryBacking>' /etc/libvirt/qemu/"$i".xml;
    fi
  done
  echo "Configured."
}

function max_numa(){
  max=${NUMA[0]}
  index=0
  for ((i=0; i<=$numanum -1; i++))
  do
    if [[ ${NUMA[${i}]} -gt $max ]]; then
      max=${NUMA[${i}]}
      index=$i
    fi
  done
  echo $index
}

function max_socket(){
  max=${Socket[0]}
  index=0
  for ((i=0; i<=$socketnum -1; i++))
  do
    if [[ ${Socket[${i}]} -gt $max ]]; then
      max=${Socket[${i}]}
      index=$i
    fi
  done
  echo $index
}

function NUMA_Aware(){
  echo "Start configuring NUMA Aware."
  
  #Init NUMA info
  corenum=`lscpu | sed -n 3p | awk '{print $2}'`
  numanum=`lscpu | grep "NUMA node(s):" | awk '{print $3}'`
  corepernuma=$[ $corenum / $numanum ]
  socketnum=`lscpu | grep "Socket(s):" | awk '{print $2}'`
  corepersocket=$[ $corenum / $socketnum ]
  numapersocket=$[ $numanum / $socketnum ]
  
  read -p "The physical machine needs to reserve CPU resources. Please enter the number of CPUs(0-24).(The recommended value is 4.) " input
  case "$input" in
  [0-9]*)
    if [[ $input -gt $corepernuma ]]; then
      echo "Too many reserved CPUs."
      restoreconfig
      exit 1
    else
      reservecpunum=$input
    fi
    ;;
  *)
    echo "Invalid input."
    restoreconfig
    exit 1
    ;;
  esac  

  declare -a NUMA
  for ((i=0; i<=$numanum - 1; i++))
  do
    NUMA[i]=$corepernuma
  done
  NUMA[0]=`expr ${NUMA[0]} - $reservecpunum`

  declare -a Socket
  for ((i=0; i<=$socketnum - 1; i++))
  do
    Socket[i]=$corepersocket
  done
  Socket[0]=`expr ${Socket[0]} - $reservecpunum`

  #The maximum CPU overscore is 1: 3
  for ((i=0; i<=$numanum - 1; i++))
  do
    NUMA[i]=`expr ${NUMA[i]} \* 3`
  done
  
  for ((i=0; i<=$socketnum - 1; i++))
  do
    Socket[i]=`expr ${Socket[i]} \* 3`
  done

  #Get the number of vCPU cores and check whether memory allocation overflows.
  cp ./backup/vmlist.txt ./backup/vmcorelist.txt
  allocated_mem=0
  mem_total_kb=`cat /proc/meminfo | grep MemTotal | tr -cd "[0-9]"`
  mem_avail_kb=`expr $mem_total_kb \* 85 \/ 100`
  for ((i=1; i<=$vmnum; i++))
  do
    vmname=`cat ./backup/vmlist.txt | sed -n "$i"p`
    vcpuconfline=`cat /etc/libvirt/qemu/"$vmname".xml | grep "  <vcpu placement="`
    coretemp=`echo ${vcpuconfline#*>}`
    core=`echo ${coretemp%<*}`
    sed -i "${i}c ${vmname} ${core}" ./backup/vmcorelist.txt
    memconfline=`cat /etc/libvirt/qemu/"$vmname".xml | grep "  <memory unit="`
    memtemp=`echo ${memconfline#*>}`
    mem=`echo ${memtemp%<*}`
    allocated_mem=`expr $allocated_mem + $mem`
    if [[ $allocated_mem -gt $mem_avail_kb ]]; then
      echo "The number of allocated memory exceeds the limit. Please reduce the specifications."
      restoreconfig
      exit 1
    fi
  done
  cat ./backup/vmcorelist.txt | sort -r -n -k2 > ./backup/vmcoresort.txt
  rm -f ./backup/vmcorelist.txt

  #Configure NUMA Aware
  for ((vmlineno=1; vmlineno<=$vmnum; vmlineno++))
  do
    vmname=`cat ./backup/vmcoresort.txt | sed -n "$vmlineno"p | awk '{print $1}' `
    core=`cat ./backup/vmcoresort.txt | sed -n "$vmlineno"p | awk '{print $2}' `
    if [[ $core -gt $corenum ]]; then
      echo "The number of vCPU cores of $vmname has exceeded the number of CPU cores of the physical machine. Please reduce the specifications."
      restoreconfig
      exit 1
    elif [[ $core -gt $corepersocket ]]; then
      bindpersockettemp=`expr $core + $socketnum - 1`
      bindpersocket=`expr $bindpersockettemp \/ $socketnum`
      for ((i=0; i<=$socketnum -1; i++))
      do
        Socket[i]=`expr ${Socket[i]} - $bindpersocket`
      done
      bindpernumatemp=`expr $core + $numanum - 1`
      bindpernuma=`expr $bindpernumatemp \/ $numanum`
      for ((i=0; i<=$numanum - 1; i++))
      do
        NUMA[i]=`expr ${NUMA[i]} - $bindpernuma`
      done
    elif [[ $core -gt $corepernuma ]]; then
      i=`max_socket`
	  if [[ $i -ne 0 ]]; then
        startcore=`expr $corepersocket \* $i`
        endcore=`expr $startcore + $corepersocket - 1`
        sed -i "/<vcpu placement=/a\  <cputune>\n    <emulatorpin cpuset='$startcore-$endcore'/>\n  </cputune>" /etc/libvirt/qemu/"$vmname".xml;
      else
        endcore=`expr $corepersocket - 1`
        sed -i "/<vcpu placement=/a\  <cputune>\n    <emulatorpin cpuset='$reservecpunum-$endcore'/>\n  </cputune>" /etc/libvirt/qemu/"$vmname".xml;
      fi
      Socket[i]=`expr ${Socket[i]} - $core`
      startnuma=`expr $numapersocket \* $i`
      endnuma=`expr $startnuma + $numapersocket`
      bindpernumatemp=`expr $core + $numapersocket - 1`
      bindpernuma=`expr $bindpernumatemp \/ $numapersocket`
      for (( n=$startnuma; n<$endnuma; n++))
      do
        NUMA[n]=`expr ${NUMA[n]} - $bindpernuma`
      done
    else
      i=`max_numa`
	  if [[ $i -ne 0 ]]; then
        startcore=`expr $corepernuma \* $i`
        endcore=`expr $startcore + $corepernuma - 1`
        sed -i "/<vcpu placement=/a\  <cputune>\n    <emulatorpin cpuset='$startcore-$endcore'/>\n  </cputune>\n  <numatune>\n    <memory mode='strict' nodeset='$i'/>\n  </numatune>" /etc/libvirt/qemu/"$vmname".xml;
      else
        endcore=`expr $corepernuma - 1`
        sed -i "/<vcpu placement=/a\  <cputune>\n    <emulatorpin cpuset='$reservecpunum-$endcore'/>\n  </cputune>\n  <numatune>\n    <memory mode='strict' nodeset='0'/>\n  </numatune>" /etc/libvirt/qemu/"$vmname".xml;
      fi
      NUMA[i]=`expr ${NUMA[i]} - $core`
      socketindex=`expr $i \/ $numapersocket`
      Socket[$socketindex]=`expr ${Socket[$socketindex]} - $core`
    fi
    #Check if the number of vcpus exceeds the limit
    for ((i=0; i<=$socketnum -1; i++))
    do
      if [[ ${Socket[i]} -lt 0 ]]; then
        echo "The number of vcpus exceeds the limit. Please reduce the specifications."
        restoreconfig
        exit 1
      fi
    done
    for ((i=0; i<=$numanum -1; i++))
    do
      if [[ ${NUMA[i]} -lt 0 ]]; then
        echo "The number of vcpus exceeds the limit. Please reduce the specifications."
        restoreconfig
        exit 1
      fi
    done
  done
}

#Environmental restoration after tuning
function restoreaftertuning(){
  echo "Start to restore the original configuration."
  if [ -f "./backup/grub.cfg.bak" ]; then
    /bin/cp -f ./backup/grub.cfg.bak $grub
  fi
  if [ -d "./backup/vmconfig" ]; then
    /bin/cp -rf ./backup/vmconfig/* /etc/libvirt/qemu
    vmnum=`awk '{print NR}' ./backup/vmlist.txt | tail -n1`
    for ((i=1; i<=$vmnum; i++))
    do
      vmname=`cat ./backup/vmlist.txt | sed -n "$i"p`
      virsh define /etc/libvirt/qemu/"$vmname".xml
    done
  fi
}

#Environmental inspection after tuning
function verify(){
  vmnum=`awk '{print NR}' ./backup/vmlist.txt | tail -n1`
  corenum=`lscpu | sed -n 3p | awk '{print $2}'`
  numanum=`lscpu | grep "NUMA node(s):" | awk '{print $3}'`
  corepernuma=$[ $corenum / $numanum ]
  socketnum=`lscpu | grep "Socket(s):" | awk '{print $2}'`
  corepersocket=$[ $corenum / $socketnum ]
  numapersocket=$[ $numanum / $socketnum ]
  
  #Check transparent hugepage config
  read -p "May I ask if you use this tool to configure transparent hugepage? [y/n]" input
	case $input in
	y|Y|[yY][eE][sS])
      if [[ -n `cat /sys/kernel/mm/transparent_hugepage/enabled | grep "always\ madvise\ \[never\]"` ]]; then
        echo "Configure transparent hugepage successfully."
      else
        echo "Failed to configure transparent hugepage."
        exit 1
      fi
	  ;;
	n|N|[nN][oO]) 
	  echo "No need to verify for transparent hugepage."
	  ;;
	*)
      echo "Invalid input."
      exit 1
      ;;
    esac
	
  #Check 512M hugepage config
  read -p "May I ask if you use this tool to configure 512M hugepage? [y/n]" input
	case $input in
	y|Y|[yY][eE][sS])
      mem_total_kb=`cat /proc/meminfo | grep MemTotal | tr -cd "[0-9]"`
      mem_avail_mb=$(echo "$mem_total_kb * 0.85 / 1024"|bc)
      numanum=`lscpu | grep "NUMA node(s):" | awk '{print $3}'`
      hugepagenum=$[$mem_avail_mb / 512 / $numanum * $numanum]
      total=`cat /proc/sys/vm/nr_hugepages`
      if [ $hugepagenum != $total ]; then
        echo "It is recommended to configure the number of hugepages to $hugepagenum, but the number of current hugepages is $total."
        exit 1
      fi
      for i in `cat ./backup/vmlist.txt`;
      do
        if [[ ! -n `cat /etc/libvirt/qemu/"$i".xml | grep "  <memoryBacking>"` ]]; then
          echo "Failed to configure <memoryBacking>"
          exit 1
        fi
        if [[ ! -n `cat /etc/libvirt/qemu/"$i".xml | grep "    <hugepages/>"` ]]; then
          echo "Failed to configure <hugepages/>"
          exit 1
        fi
        if [[ ! -n `cat /etc/libvirt/qemu/"$i".xml | grep "  </memoryBacking>"` ]]; then
          echo "Failed to configure </memoryBacking>"
          exit 1
        fi
        line=`cat /etc/libvirt/qemu/"$i".xml | grep -n "  <memoryBacking>" | awk '{print $1}' | tr -cd "[0-9]"`
        line1=`cat /etc/libvirt/qemu/"$i".xml | grep -n "    <hugepages/>" | awk '{print $1}' | tr -cd "[0-9]"`
        line2=`cat /etc/libvirt/qemu/"$i".xml | grep -n "  </memoryBacking>" | awk '{print $1}' | tr -cd "[0-9]"`
        if [[ $[$line1 - $line] != 1 || $[$line2 - $line] != 2 ]]; then
          echo "Hugepage configuration of "$i" is not continuous"
		  exit 1
        fi
      done
      echo "Configure hugepage successfully."
	  ;;
	n|N|[nN][oO]) 
	  echo "No need to verify for 512M hugepage."
	  ;;
	*)
      echo "Invalid input."
      exit 1
      ;;
    esac

  #Check VMs xml config for NUMA Aware
  read -p "May I ask if you use this tool to configure xml files of VMs for NUMA Aware? [y/n]" input
	case $input in
	y|Y|[yY][eE][sS])
      for ((i=1; i<=$vmnum; i++))
      do
        vmname=`cat ./backup/vmcoresort.txt | sed -n "$i"p | awk '{print $1}' `
        core=`cat ./backup/vmcoresort.txt | sed -n "$i"p | awk '{print $2}' `
        if [[ $core -le $corepersocket ]]; then
          if [[ ! -n `cat /etc/libvirt/qemu/"$vmname".xml | grep "  <cputune>"` ]]; then
            echo "Failed to configure NUMA Aware(cputune) for "$vmname"."
            exit 1
          fi
        fi
		if [[ $core -le $corepernuma ]]; then
          if [[ ! -n `cat /etc/libvirt/qemu/"$vmname".xml | grep "  <numatune>"` ]]; then
            echo "Failed to configure NUMA Aware(numatune) for "$vmname"."
            exit 1
          fi
        fi
      done
	  echo "Configure cputune and numatune successfully."
	  ;;
	n|N|[nN][oO]) 
	  echo "No need to verify for NUMA Aware."
	  ;;
	*)
      echo "Invalid input."
      exit 1
      ;;
    esac
}

#Tuning
function tuning(){

  #Create a backup folder
  mkdir ./backup
  
  #Back up grub.cfg
  /bin/cp -f $grub ./backup/grub.cfg.bak
  
  #Backup and Modify virtual machine xml files
  /bin/cp -rf /etc/libvirt/qemu ./backup/vmconfig

  #Get current vm list
  virsh list --all | awk 'NR>3{print p}{p=$0}' | awk '{print $2}'> ./backup/vmlist.txt
  vmnum=`awk '{print NR}' ./backup/vmlist.txt | tail -n1`

  #Close the transparent hugepage
  if [[ -n `cat /sys/kernel/mm/transparent_hugepage/enabled | grep "always\ madvise\ \[never\]"` ]]; then
    echo "The transparent hugepage has been closed in the system"
  else
    read -p "Would you like to close the transparent hugepage as suggested? [y/n]" input
	case $input in
	y|Y|[yY][eE][sS])
      close_transparent_hugepage
	  ;;
	n|N|[nN][oO]) 
	  echo "No need to change the configuration file."
	  ;;
	*)
      echo "Invalid input."
      restoreconfig
      exit 1
      ;;
    esac  
  fi
  
  #Configure 512MB hugepage
  total=`cat /proc/sys/vm/nr_hugepages`
  if [[ $total -ne 0 ]]; then
    read -p "Hugepage has been configured in the system. Would you like to modify the configuration as suggested? [y/n]" input
    case $input in
    y|Y|[yY][eE][sS])
      configure_512M_hugepage
      ;;
    n|N|[nN][oO]) 
      echo "No need to change the configuration file."
      ;;
    *)
      echo "Invalid input."
      restoreconfig
      exit 1
      ;;
    esac  
  else
    read -p "Would you like to configure 512M hugepage as suggested? [y/n]" input
	case $input in
    y|Y|[yY][eE][sS])
      configure_512M_hugepage
	  ;;
	n|N|[nN][oO]) 
      echo "No need to change the configuration file."
      ;;
    *)
      echo "Invalid input."
      restoreconfig
      exit 1
      ;;
    esac
  fi

  #Configure NUMA Aware
  read -p "Whether the configurations of all virtual machines are the initial configurations at the time of creation [y/n]" input
  case $input in
  y|Y|[yY][eE][sS])
    read -p "Would you like to configure NUMA Aware as suggested? [y/n]" idea
    case $idea in
    y|Y|[yY][eE][sS])
      read -p "May I ask if all the machines are powered off? [y/n]" shutdown
      case $shutdown in
      y|Y|[yY][eE][sS])
        virsh list > whethershutdown.txt
	    if [ ! -n "`cat whethershutdown.txt | sed -n 3p`" ]; then
          rm -f whethershutdown.txt
          NUMA_Aware
	    else
          rm -f whethershutdown.txt
          echo "Please power off all virtual machines."
	      restoreconfig
	      exit 1
        fi
	    ;;
      n|N|[nN][oO])
        echo "Please power off all virtual machines."
        restoreconfig
        exit 1
	    ;;
      *)
        echo "Invalid input."
        restoreconfig
        exit 1
        ;;
      esac
      ;;
    n|N|[nN][oO])
      echo "No need to configure NUMA Aware."
      ;;
    *)
      echo "Invalid input."
      restoreconfig
      exit 1
      ;;
    esac
    ;;
  n|N|[nN][oO])
    echo "The tool does not support modification of non-initial configuration, please configure refer to the tuning guide manually."
    restoreconfig
    exit 1
    ;;
  *)
    echo "Invalid input."
    restoreconfig
    exit 1
    ;;
  esac
  
  #define VM xml file
  for ((i=1; i<=$vmnum; i++))
  do
    vmname=`cat ./backup/vmlist.txt | sed -n "$i"p`
    virsh define /etc/libvirt/qemu/"$vmname".xml
  done
}

if [[ $# -ne 1 ]] || [[ "$1" != "tuning" ]] && [[ "$1" != "verify" ]] && [[ "$1" != "restore" ]]; then
  usage
  exit 1
else
  read -p "Please input the grub directory:" grub
  echo "Your grub directory: $grub"
 
  #Create a backup folder
  mkdir ./backup
 
  #Get current vm list
  virsh list --all | awk 'NR>3{print p}{p=$0}' | awk '{print $2}'> ./backup/vmlist.txt
  vmnum=`awk '{print NR}' ./backup/vmlist.txt | tail -n1`

  #Init NUMA info
  corenum=`lscpu | sed -n 3p | awk '{print $2}'`
  numanum=`lscpu | grep "NUMA node(s):" | awk '{print $3}'`
  corepernuma=$[ $corenum / $numanum ]
  socketnum=`lscpu | grep "Socket(s):" | awk '{print $2}'`
  corepersocket=$[ $corenum / $socketnum ]
  numapersocket=$[ $numanum / $socketnum ]
 

  action="$1"
  if [ $action == "tuning" ]; then
    echo "Start tuning."
    tuning
	echo "Reboot host OS for the configuration to take effect."
  fi
  if [ $action == "verify" ]; then
    echo "Start verifying."
    verify
  fi
  if [ $action == "restore" ]; then
    echo "Start restoring."
    restoreaftertuning
	echo "Reboot host OS for the configuration to take effect."
  fi
fi
