#!/bin/bash -e

LANG=C
PTPCAM='/usr/local/bin/ptpcam'
ZOOM=23

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

function switch_to_record_mode {
  echo "Switching cameras to record mode..."
  echo "$LEFTCAM is LEFTCAM and $RIGHTCAM is RIGHTCAM"
  echo "Switching left camera to record mode and sleeping 1 second..."
  $PTPCAM --dev=$LEFTCAM --chdk='mode 1' > /dev/null 2>&1 && sleep 1s
  echo "Switching right camera to record mode and sleeping 1 second..."
  $PTPCAM --dev=$RIGHTCAM --chdk='mode 1' > /dev/null 2>&1 && sleep 1s
  sleep 3s
}


function set_zoom {
  # TODO: make less naive about zoom setting (check before and after setting, ...)
  echo "Setting cameras zoom to $ZOOM..."
  echo "Setting left camera zoom to $ZOOM..."
  $PTPCAM --dev=$LEFTCAM --chdk="lua while(get_zoom()~=$ZOOM) do set_zoom($ZOOM) end"
  echo "Setting right camera zoom to $ZOOM..."
  $PTPCAM --dev=$RIGHTCAM --chdk="lua while(get_zoom()~=$ZOOM) do set_zoom($ZOOM) end"
  sleep 3s
}

function set_focus {
  echo "Setting cameras focus..."
  echo "Setting left camera focus to $FOCUS..."
  $PTPCAM --dev=$LEFTCAM --chdk="lua set_mf(1)"
  $PTPCAM --dev=$LEFTCAM --chdk="lua set_focus($FOCUS)"
  echo "Setting left camera focus to $FOCUS..."
  $PTPCAM --dev=$LEFTCAM --chdk="lua set_mf(1)"
  $PTPCAM --dev=$LEFTCAM --chdk="lua set_focus($FOCUS)"
}

function flash_off {
  echo "Switching flash off..."
  $PTPCAM --dev=$LEFTCAM --chdk='lua while(get_flash_mode()<2) do click("right") end'
  $PTPCAM --dev=$RIGHTCAM --chdk='lua while(get_flash_mode()<2) do click("right") end'
}

function set_iso {
    #echo "Setting ISO mode to 1 for left cam."
    ptpcam --dev=$LEFTCAM --chdk="lua set_iso_real(50)"
    #echo "Setting ISO mode to 1 for right cam."
    ptpcam --dev=$RIGHTCAM --chdk="lua set_iso_real(50)"
}

function set_ndfilter {
    #echo "Disabling neutrality density filter for $LEFTCAM. See http://chdk.wikia.com/wiki/ND_Filter."
    ptpcam --dev=$LEFTCAM --chdk="luar set_nd_filter(2)"
    echo "Disabling neutrality density filter for $RIGHTCAM. See http://chdk.wikia.com/wiki/ND_Filter."
    ptpcam --dev=$RIGHTCAM --chdk="luar set_nd_filter(2)"
}

# The action starts here

detect_cams
switch_to_record_mode
set_zoom
flash_off
set_iso
set_ndfilter

$PTPCAM --dev=$LEFTCAM --chdk='lua play_sound(0)'

# Shooting loop
echo "Starting focus calibration..."
for focus in {70..100}; do
    set_iso
    # shutter speed needs to be set before every shot
    $PTPCAM --dev=$LEFTCAM --chdk="luar set_tv96(320)"
    $PTPCAM --dev=$LEFTCAM --chdk='lua set_focus($focus)'
	sleep 1s
    $PTPCAM --dev=$LEFTCAM --chdk='lua shoot()'
    sleep 2s
    # shutter speed needs to be set before every shot
    $PTPCAM --dev=$RIGHTCAM --chdk="luar set_tv96(320)"
    $PTPCAM --dev=$RIGHTCAM --chdk='lua set_focus($focus)'
	sleep 1s
    $PTPCAM --dev=$RIGHTCAM --chdk='lua shoot()'
    sleep 2s
    echo "Left set to $focus, got $($PTPCAM --dev=$LEFTCAM --chdk="luar get_focus()")"
    echo "Right set to $focus, got $($PTPCAM --dev=$RIGHTCAM --chdk="luar get_focus()")"
    sleep 1s
  fi
done # end shooting loop

