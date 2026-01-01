#!/bin/bash

clipboard=$(xclip -o -selection clipboard -target text/plain 2>/dev/null)
if [[ -z $clipboard ]]; then
    # This is not plaintext, check whether it's image/bmp
    clipboard=$(xclip -o -selection clipboard -target image/bmp)
    if [[ -n $clipboard ]]; then
        echo "It's a picture."
        # It's an image, make a tempdir and save it as a bmp file
        tempdir=$(mktemp -d)

        # Set up a trap to clean up the tempdir on exit
        trap 'rm -rf "$tempdir"' EXIT
        bmpfile="$tempdir/clipboard_image.bmp"
        xclip -o -selection clipboard -target image/bmp > "$bmpfile"
        # Resize the image to width 384 pixel monochrome using ImageMagick
        # convert "$bmpfile" -gravity center -extent 384x384^\> -background black -flip -monochrome "$tempdir/clipboard_image_mono.bmp"
        convert "$bmpfile" -resize 384x384 -gravity center -extent 384x384 -background black -flip -monochrome "$tempdir/clipboard_image_mono.bmp"
        # open "$tempdir/clipboard_image_mono.bmp"
        # exit 0
        cat "$tempdir/clipboard_image_mono.bmp" | tail -c $(((384*384)/8)) | mosquitto_pub -s -h picard -u myUsername -P myPassword -t 'root_topic/receipt_printer/print_bitmap'
        mosquitto_pub -h mqtt_broker_ip -u myUsername -P myPassword -t "root_topic/receipt_printer/print_text" -m ""
        mosquitto_pub -h mqtt_broker_ip -u myUsername -P myPassword -t "root_topic/receipt_printer/print_text" -m ""
        mosquitto_pub -h mqtt_broker_ip -u myUsername -P myPassword -t "root_topic/receipt_printer/print_text" -m ""
        notify-send "Receipt Printer" "Printed clipboard content (image)."
        exit 0
    fi
    notify-send "Receipt Printer" "Clipboard is empty, not printing."
    exit 0
fi
# If the clipboard contains more than 500 characters, don't print it
if [[ ${#clipboard} -gt 1000 ]]; then
    notify-send "Receipt Printer" "Clipboard content is too long (${#clipboard} characters), not printing."
    exit 0
fi
# For each line in the clipboard
while IFS= read -r line; do
    # Strip leading and trailing whitespace
    line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')
    mosquitto_pub -h mqtt_broker_ip -u myUsername -P myPassword -t "root_topic/receipt_printer/print_text" -m "$line"
done <<< "$clipboard"
mosquitto_pub -h mqtt_broker_ip -u myUsername -P myPassword -t "root_topic/receipt_printer/print_text" -m ""
mosquitto_pub -h mqtt_broker_ip -u myUsername -P myPassword -t "root_topic/receipt_printer/print_text" -m ""
mosquitto_pub -h mqtt_broker_ip -u myUsername -P myPassword -t "root_topic/receipt_printer/print_text" -m ""
notify-send "Receipt Printer" "Printed clipboard content (${#clipboard} characters)."
