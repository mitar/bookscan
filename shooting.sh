#!/bin/bash -e

LANG=C
PTPCAM='/usr/local/bin/ptpcam'
ZOOM=23
FOCUS=381

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
  $PTPCAM --dev=$LEFTCAM --chdk='mode 1'
  $PTPCAM --dev=$RIGHTCAM --chdk='mode 1'
  sleep 3s
}

function set_zoom {
  # TODO: make less naive about zoom setting (check before and after setting, ...)
  echo "Setting cameras zoom to $ZOOM..."
  $PTPCAM --dev=$LEFTCAM --chdk="lua while(get_zoom()~=$ZOOM) do set_zoom($ZOOM) end"
  $PTPCAM --dev=$RIGHTCAM --chdk="lua while(get_zoom()~=$ZOOM) do set_zoom($ZOOM) end"
  sleep 3s
}

function flash_off {
  echo "Switching flash off..."
  $PTPCAM --dev=$LEFTCAM --chdk='lua while(get_flash_mode()<2) do click("right") end'
  $PTPCAM --dev=$RIGHTCAM --chdk='lua while(get_flash_mode()<2) do click("right") end'
  sleep 1s
}

function set_iso {
  $PTPCAM --dev=$LEFTCAM --chdk="lua set_iso_real(50)"
  $PTPCAM --dev=$RIGHTCAM --chdk="lua set_iso_real(50)"
}

function set_ndfilter {
  # See http://chdk.wikia.com/wiki/ND_Filter
  $PTPCAM --dev=$LEFTCAM --chdk="luar set_nd_filter(2)"
  $PTPCAM --dev=$RIGHTCAM --chdk="luar set_nd_filter(2)"
}

# The action starts here

detect_cams
switch_to_record_mode
set_zoom
flash_off

$PTPCAM --dev=$LEFTCAM --chdk='lua play_sound(0)'
$PTPCAM --dev=$RIGHTCAM --chdk='lua play_sound(0)'

# Shooting loop
echo "Starting shooting loop..."
while true; do
  # watch foot pedal if it is pressed
  read -n1 shoot
  if [ "$shoot" == "b" ]; then
    echo "Key pressed."
    echo "Shooting with cameras $LEFTCAM (left) and $RIGHTCAM (right)"
    set_iso
    $PTPCAM --dev=$LEFTCAM --chdk="lua set_user_tv96(320)"
    $PTPCAM --dev=$RIGHTCAM --chdk="lua set_user_tv96(320)"
    set_ndfilter
    $PTPCAM --dev=$LEFTCAM --chdk="lua set_focus($FOCUS)"
    $PTPCAM --dev=$RIGHTCAM --chdk="lua set_focus($FOCUS)"
    sleep 1s
    $PTPCAM --dev=$LEFTCAM --chdk='lua shoot()'
    sleep 1s # So that it is easier to hear both shoots
    $PTPCAM --dev=$RIGHTCAM --chdk='lua shoot()'
    sleep 3s
  fi
done # end shooting loop

