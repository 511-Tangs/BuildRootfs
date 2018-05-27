#!/bin/bash
CWD=`pwd`

if [  "x`which sshfs`" = "x" -o "x`which fusermount`" = "x" -o  "x`which rmnt`" = "x" ]
  then echo "sshfs, fusermount, or rmnt commands not found, install sshfs, fuse packages"
       echo "or /usr/local/bin/rmnt shell script and symbolically link it to rumnt." 
       exit 1
fi

if [ -d $HOME/ChLaTeX ]
  then cd $HOME/ChLaTeX; rm -rf *
else mkdir -p $HOME/ChLaTeX 
  cd $HOME/ChLaTeX 
fi 

if [ ! -d /mnt/rfs ]
  then sudo mkdir /mnt/rfs; sudo chown `whoami`:`whoami` /mnt/rfs 
elif [ ! -w /mnt/rfs -o ! -x /mnt/rfs ] 
  then sudo chown `whoami`:`whoami` /mnt/rfs 
else echo "We are in good shape."
fi

rmnt as:/backup/ChLaTeX 
# mounting remote dir: as:/backup/ChLaTeX...
# hsu@as's password: 
# Type password 

if [ $? -eq 0 ] 
  then tar -zxvf /mnt/rfs/ChLaTeX-*.tgz 
    if [ ! $? -eq 0 ] 
      then echo "tar -zxvf /mnt/rfs/ChLaTeX-*.tgz failed, Bail out." 
           rumnt
           exit 2
    else echo "ChLaTeX related files successfully installed."
         rumnt
    fi
else echo "rmnt as:/backup/ChLaTeX failed, Bail out."
     rumnt
     exit 3
fi 

rmnt as:/backup/ChFont 
# mounting remote dir: as:/backup/ChFont...
# hsu@as's password: 
# Type password 
# -rw-r--r-- 1 hsu hsu 61890835 Jan 22 16:33 ChFont-2018-01-22.tgz

if [  $? -eq 0 ]
  then if [ ! -d usr/local/share/texmf/fonts ]
         then mkdir -p usr/local/share/texmf/fonts
       else echo "usr/local/share/texmf/fonts directory exists, override?: [y/n] " 
            read Answer
            case "$Answer" in
              y)  cd usr/local/share/texmf/fonts  
                  rm -rf *
                  cd ../../../../.. ;;
              *)  echo "Don't know what to do, quit." >&2
                  exit 5;;
            esac 
       fi
else echo "Fail to mount as:/backup/ChFont, Bail out."
     rumnt 
     exit 6
fi

if [ -f /mnt/rfs/ChFont-*.tgz ]
  then tar -zxvf /mnt/rfs/ChFont-*.tgz 
else echo "tared font file:/mnt/rfs/ChFont-*.tgz does not exist."
     exit 7
fi 

if [  $? -eq 0 ] 
  then if [ -f usr/local/share/texmf/fonts/pk/cx/cheuc/chfs834.300pk ]
         then echo "Got chfs834.300pk font file already."  
              rumnt
       else echo "chfs834.300pk missing, something wrong about font files, Bail out."
            rumnt
            exit 8
       fi
else echo "Fail to untar /mnt/rfs/ChFont-*.tgz" 
     rumnt
     exit 9
fi

if [ -f /usr/local/share/texmf/fonts/pk/cx/cheuc/chfs946.300pk -o \
       -f /usr/local/share/texmf/fonts/pk/ljfour/cheuc/chfs946.600pk ]
  then echo "It seems pk files for ChLaTeX already existed, override? [y/n] "
       read Answer
       case "$Answer" in
         y)  sudo rm -rf /usr/local/share/texmf/fonts/* ;;
         *)  echo "Don't know what to do, quit." >&2
             exit 10;;
       esac 
elif [ ! -d /usr/local/share/texmf/fonts ]
  then sudo mkdir -p /usr/local/share/texmf/fonts 
else echo "Ready to install cheuc fonts."
fi

# Now, we are ready to install cheuc fonts.
cd usr/local/share/texmf/fonts 
find . -print | sudo cpio -pdm /usr/local/share/texmf/fonts
cd ../../../../..

if [ -f /usr/local/share/texmf/fonts/pk/cx/cheuc/chfs946.300pk ]
  then echo "It seems font files installed successfully."
fi 

#  It seems Debian no longer use /var/cache/fonts directory.
#  Let us end here.

if [ ! -d /usr/local/share/texmf/tex ]
  then sudo mkdir -p /usr/local/share/texmf/tex
fi

if [ ! -d $HOME/ChLaTeX/usr/local/share/texmf/tex ]
  then echo "It seems ChLaTeX implementation files do not exist."
       exit 11 
fi 

cd $HOME/ChLaTeX/usr/local/share/texmf/tex
find . -print | sudo cpio -pdm /usr/local/share/texmf/tex

cd /usr/local/share/texmf/ 
sudo mktexlsr . 

if [ -d /var/lib/texmf/fonts/tfm/cheuc ]
  then echo "Old cheuc font files still exist, clean them up? [y/n]" 
       read Answer
       case "$Answer" in
         y)  sudo rm -rf /var/lib/texmf/fonts/pk 
             sudo rm -rf /var/lib/texmf/fonts/tfm 
             cwd=`pwd`
             cd /var/lib/texmf 
             sudo mktexlsr . 
             cd ${cwd};;
         *)  echo "Don't know what to do, quit." >&2
             exit 12;;
       esac 
fi

echo "Now you are ready to modify texmf.cnf and execute texhash."
cd $CWD

