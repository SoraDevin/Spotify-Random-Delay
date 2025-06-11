#!/bin/bash

# Function to get Spotify status
get_spotify_status() {
    dbus-send --print-reply \
              --dest=org.mpris.MediaPlayer2.spotify \
              /org/mpris/MediaPlayer2 \
              org.freedesktop.DBus.Properties.Get \
              string:'org.mpris.MediaPlayer2.Player' \
              string:'PlaybackStatus' \
    | grep -o '"Playing"' | sed 's/"//g'
}

# Function to pause Spotify
pause_spotify() {
    dbus-send --print-reply \
              --dest=org.mpris.MediaPlayer2.spotify \
              /org/mpris/MediaPlayer2 \
              org.mpris.MediaPlayer2.Player.Pause
}

# Function to play Spotify
play_spotify() {
    dbus-send --print-reply \
              --dest=org.mpris.MediaPlayer2.spotify \
              /org/mpris/MediaPlayer2 \
              org.mpris.MediaPlayer2.Player.Play
}

# Function to get the position of the current track in microseconds
get_track_position() {
    dbus-send --print-reply \
              --dest=org.mpris.MediaPlayer2.spotify \
              /org/mpris/MediaPlayer2 \
              org.freedesktop.DBus.Properties.Get \
              string:'org.mpris.MediaPlayer2.Player' \
              string:'Position' \
    | grep -o 'int64 [0-9]*' | awk '{print $2}'
}

# Function to get the length of the current track in microseconds
get_track_length() {
    dbus-send --print-reply \
              --dest=org.mpris.MediaPlayer2.spotify \
              /org/mpris/MediaPlayer2 \
              org.freedesktop.DBus.Properties.Get \
              string:'org.mpris.MediaPlayer2.Player' \
              string:'Metadata' \
    | grep -A 1 "mpris:length" | grep -o 'variant.*int64 [0-9]*' | awk '{print $3}'
}

# Main loop
new_song=false
current_track_id=""

while true; do
    if [ "$(get_spotify_status)" = "Playing" ]; then
        current_position=$(get_track_position)
        #track_length=$(get_track_length)
	tolerance=1000000 # 1s in us

        #echo "Pos: $current_position"
        #echo "Len: $track_length"
	#echo "new song: $new_song"

	# Get the unique track ID to detect song changes
        new_track_id=$(dbus-send --print-reply \
                                 --dest=org.mpris.MediaPlayer2.spotify \
                                 /org/mpris/MediaPlayer2 \
                                 org.freedesktop.DBus.Properties.Get \
                                 string:'org.mpris.MediaPlayer2.Player' \
                                 string:'Metadata' \
                        | grep -A 1 "mpris:trackid" | tail -n 1 | awk -F '"' '{print $2}')

	#echo "Current Track ID: $new_track_id"

	# Reset the pause flag if the track changes
        if [ "$current_track_id" != "$new_track_id" ]; then
            current_track_id="$new_track_id"
            new_song=false
        fi

        # Check if both position and length are integers
        if [[ "$current_position" =~ ^[0-9]+$ ]]; then # && [[ "$track_length" =~ ^[0-9]+$ ]]; then

            if [ "$current_position" -le "$tolerance" ] && [ "$new_song" = false ]; then
		# Pause Spotify and add a random delay
               	pause_spotify
       	        delay=$((RANDOM % 100 + 50)) # Random delay between 5 and 15 seconds
                echo "Pausing for $delay seconds..."
               	sleep "$delay"
       	        play_spotify
		new_song=true
            fi
        else
            echo "Error: Invalid position or length detected. Retrying..."
        fi
    fi
    sleep 0.1
done
