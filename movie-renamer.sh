#!/bin/bash

# function
function get-mal-id () {
jq ".[] | select(".imdb_id" == ${imdb_id} )" -r $SCRIPT_FOLDER/pmm_anime_ids.json |jq ."mal_id" | sort -n | head -1
}
function get-mal-infos () {
wget "https://api.jikan.moe/v4/anime/$mal_id" -O $SCRIPT_FOLDER/infos/$mal_id.json 
sleep 1.2
}
function get-mal-title () {
jq .data.title -r $SCRIPT_FOLDER/infos/$mal_id.json
}
function get-mal-rating () {
jq .data.score -r $SCRIPT_FOLDER/infos/$mal_id.json
}
function get-mal-poster () {
mal_poster_url=$(jq .data.images.jpg.large_image_url -r $SCRIPT_FOLDER/infos/$mal_id.json)
wget "$mal_poster_url" -O $SCRIPT_FOLDER/posters/$mal_id.jpg
sleep 2
}

## folder and file emplacement
SCRIPT_FOLDER=/home/arialz/github/Plex-Animes-Renamer
PMM_FOLDER=/home/plexmetamanager
LOG_PATH=/home/arialz/log/movies-renamer_$(date +%Y.%m.%d).log
animes_titles=$PMM_FOLDER/config/animes/movies-titles.yml

# get library titles and imdb-ID list by PMM
rm $PMM_FOLDER/config/temp-movies.cache
rm $SCRIPT_FOLDER/movie.csv
cd $PMM_FOLDER
$PMM_FOLDER/pmm-venv/bin/python3 $PMM_FOLDER/plex_meta_manager.py -r --config $PMM_FOLDER/config/temp-movies.yml
mv $PMM_FOLDER/config/logs/meta.log $SCRIPT_FOLDER
line_start=$(grep -n "Mapping Animes Films Library" $SCRIPT_FOLDER/meta.log | cut -d : -f 1)
line_end=$(grep -n "Running animes-airing Metadata File" $SCRIPT_FOLDER/meta.log | cut -d : -f 1)
head -n $line_end $SCRIPT_FOLDER/meta.log | tail -n $(( $line_end -$line_start - 1 )) | head -n -5 > $SCRIPT_FOLDER/movies-cleanlog.txt
rm $SCRIPT_FOLDER/meta.log
awk -F"|" '{ OFS = "|" } ; { gsub(/ /,"",$6) } ; { print substr($6,8),substr($7,2,length($7)-2) }' $SCRIPT_FOLDER/movies-cleanlog.txt > $SCRIPT_FOLDER/list-movies.csv
rm $SCRIPT_FOLDER/movies-cleanlog.txt
curl "https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager-Anime-IDs/master/pmm_anime_ids.json" > $SCRIPT_FOLDER/pmm_anime_ids.json # get pmm animes mapping
if [ ! -f $animes_titles ] # check if $animes_titles exist
then
        echo "metadata:" > $animes_titles
fi
if [ ! -d $SCRIPT_FOLDER/infos ] # check if $animes_titles exist
then
        mkdir $SCRIPT_FOLDER/infos
else
	rm $SCRIPT_FOLDER/infos/*
fi
if [ ! -d $SCRIPT_FOLDER/posters ] # check if $animes_titles exist
then
        mkdir $SCRIPT_FOLDER/posters
fi

# get corresponding MAL title and score
while IFS="|" read -r imdb_id title_plex
do
        if [ -f $SCRIPT_FOLDER/ID-movies.csv ] # check if ID-animes.csv exist
        then
                if ! awk -F"|" '{print $1}' $SCRIPT_FOLDER/ID-movies.csv | grep $imdb_id
                then
                        if awk -F"|" '{print $1}' $SCRIPT_FOLDER/override-ID-movies.csv | tail -n +2 | grep $imdb_id                   # check if in override
                        then
                                overrideline=$(grep -n "$imdb_id" $SCRIPT_FOLDER/override-ID-movies.csv | cut -d : -f 1)
                                mal_id=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-movies.csv | awk -F"|" '{print $2}')
                                title_mal=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-movies.csv | awk -F"|" '{print $3}')
                                get-mal-infos
				echo "override found for : $title_mal / $title_plex" >> $LOG_PATH
                                echo "$imdb_id|$mal_id|$title_mal|$title_plex" >> $SCRIPT_FOLDER/ID-movies.csv
			else
                                mal_id=$(get-mal-id)
                                if [[ "$mal_title" == 'null' ]] || [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]
                                then
                                        echo "invalid MAL ID for : imdb : $imdb_id / $title_plex" >> $LOG_PATH
                                fi
				get-mal-infos
                                title_mal=$(get-mal-title)
                                echo "$imdb_id|$mal_id|$title_mal|$title_plex" >> $SCRIPT_FOLDER/ID-movies.csv
                        fi
                fi
        else
                if awk -F"|" '{print $1}' $SCRIPT_FOLDER/override-ID-movies.csv | tail -n +2 | grep $imdb_id                   # check if in override
                then
                        overrideline=$(grep -n "$imdb_id" $SCRIPT_FOLDER/override-ID-movies.csv | cut -d : -f 1)
                        mal_id=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-movies.csv | awk -F"|" '{print $2}')
                        title_mal=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-movies.csv | awk -F"|" '{print $3}')
                        get-mal-infos
			echo "override found for : $title_mal / $title_plex" >> $LOG_PATH
                        echo "$imdb_id|$mal_id|$title_mal|$title_plex" >> $SCRIPT_FOLDER/ID-movies.csv
                else
                        mal_id=$(get-mal-id)
                        if [[ "$mal_title" == 'null' ]] || [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]
                        then
                        echo "invalid MAL ID for : imdb : $imdb_id / $title_plex" >> $LOG_PATH
                        fi
			get-mal-infos
                        title_mal=$(get-mal-title)
                        echo "$imdb_id|$mal_id|$title_mal|$title_plex" >> $SCRIPT_FOLDER/ID-animes.csv
                fi
        fi
done < $SCRIPT_FOLDER/list-movies.csv
sleep 30

# write PMM metadata file
while IFS="|" read -r imdb_id mal_id title_mal title_plex
do
        if ! grep "$title_mal" $animes_titles
        then
                if [ ! -f $SCRIPT_FOLDER/infos/$mal_id.json ] # check infos from json
		then
			get-mal-infos
		fi
                echo "  \"$title_mal\":" >> $animes_titles
                echo "    alt_title: \"$title_plex\"" >> $animes_titles
                echo "    sort_title: \"$title_mal\"" >> $animes_titles
		score_mal=$(get-mal-rating)
                echo "    audience_rating: $score_mal" >> $animes_titles
                if [ ! -f $SCRIPT_FOLDER/posters/$mal_id.jpg ] # check poster
		then
			get-mal-poster
			echo "    file_poster: $SCRIPT_FOLDER/posters/${mal_id}.jpg" >> $animes_titles
		fi
		echo "added to metadata : $title_mal / $title_plex / score : $score_mal" >> $LOG_PATH
        else
                if [ ! -f $SCRIPT_FOLDER/infos/$mal_id.json ] # check infos from json
		then
			get-mal-infos
		fi
		ratingline=$(grep -n "sort_title: \"$title_mal\"" $animes_titles | cut -d : -f 1)
                ratingline=$((ratingline+1))
                if sed -n "${ratingline}p" $animes_titles | grep "audience_rating:"
                then
                        sed -i "${ratingline}d" $animes_titles
                        mal_score=$(get-mal-rating)
                        sed -i "${ratingline}i\    audience_rating: ${mal_score}" $animes_titles
                        echo "updated score : $mal_score" >> $LOG_PATH
                fi
        fi
done < $SCRIPT_FOLDER/ID-animes.csv