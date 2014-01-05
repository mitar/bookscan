#!/bin/bash -e

LANG=C
PTPCAM='/usr/local/bin/ptpcam'

function detect_cams {
  CAMS=$(gphoto2 --auto-detect|grep usb| wc -l)
  if [ $CAMS -eq 2 ]; then
    GPHOTOCAM1=$(gphoto2 --auto-detect|grep usb|sed -e 's/.*Camera *//g'|head -n1)
    GPHOTOCAM2=$(gphoto2 --auto-detect|grep usb|sed -e 's/.*Camera *//g'|tail -n1)
    echo $GPHOTOCAM1" is gphotocam1"
    echo $GPHOTOCAM2" is gphotocam2"
    
    GPHOTOCAM1ORIENTATION=$(gphoto2 --port $GPHOTOCAM1 --get-config /main/settings/ownername|grep Current|sed -e's/.*\ //')
    GPHOTOCAM2ORIENTATION=$(gphoto2 --port $GPHOTOCAM2 --get-config /main/settings/ownername|grep Current|sed -e's/.*\ //')

    echo $GPHOTOCAM1ORIENTATION" is gphotocam1orientation"
    echo $GPHOTOCAM2ORIENTATION" is gphotocam2orientation"

    CAM1=$(echo $GPHOTOCAM1|sed -e 's/.*,//g')
    CAM2=$(echo $GPHOTOCAM2|sed -e 's/.*,//g')
    echo "Detected 2 camera devices: $GPHOTOCAM1 and $GPHOTOCAM2"
  else
    echo "Number of camera devices does not equal 2. Giving up."
    exit
  fi
  if [ "$GPHOTOCAM1ORIENTATION" == "left" ]; then
    LEFTCAM=$(echo $GPHOTOCAM1|sed -e 's/.*,//g')
    LEFTCAMLONG=$GPHOTOCAM1
  elif [ "$GPHOTOCAM1ORIENTATION" == "right" ]; then
    RIGHTCAM=$(echo $GPHOTOCAM1| sed -e 's/.*,//g')
    RIGHTCAMLONG=$GPHOTOCAM1
  else
    echo "$GPHOTOCAM1 owner name is neither set to left or right. Please configure that before continuing."
    exit
  fi
  if [ "$GPHOTOCAM2ORIENTATION" == "left" ]; then
    LEFTCAM=$(echo $GPHOTOCAM2|sed -e 's/.*,//g')
    LEFTCAMLONG=$GPHOTOCAM2
  elif [ "$GPHOTOCAM2ORIENTATION" == "right" ]; then
    RIGHTCAM=$(echo $GPHOTOCAM2| sed -e 's/.*,//g')
    RIGHTCAMLONG=$GPHOTOCAM2
  else
    echo "$GPHOTOCAM2 owner name is neither set to left or right. Please configure that before continuing."
    exit
  fi
}

function delete_from_cams {
  $PTPCAM --dev=$LEFTCAM --chdk='lua play_sound(6)'
  echo "$GPHOTOCAM1: deleting existing images from SD card"
  gphoto2 --port $GPHOTOCAM1 --recurse -D -f /store_00010001/DCIM/
  echo "$GPHOTOCAM2: deleting existing images from SD card"
  gphoto2 --port $GPHOTOCAM2 --recurse -D -f /store_00010001/DCIM/
  $PTPCAM --dev=$LEFTCAM --chdk='lua play_sound(0)'
}

function download_from_cams {
    TIMESTAMP=$(date +%Y%m%d%H%M)
    echo "Downloading images from $CAM1..."
    mkdir -p ~/bookscan_$TIMESTAMP/left ~/bookscan_$TIMESTAMP/right
    cd ~/bookscan_$TIMESTAMP/left
    $PTPCAM --dev=$LEFTCAM --chdk='lua play_sound(6)'
    gphoto2 --port $LEFTCAMLONG -P -f /store_00010001/DCIM/
    cd ../right
    echo "Downloading images from $CAM2"
    gphoto2 --port $RIGHTCAMLONG -P -f /store_00010001/DCIM/ 
    cd ..
}

# The action starts here

detect_cams

$PTPCAM --dev=$LEFTCAM --chdk='lua play_sound(0)'

echo "Downloading and deleting from cameras."
download_from_cams
delete_from_cams
echo "Dowloaded and deleted from cameras."
