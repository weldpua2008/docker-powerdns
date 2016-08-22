#!/usr/bin/env bash
set -e

declare -a ADDED_TAGs

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

url='https://github.com/weldpua2008/docker-powerdns'
cat <<-EOH
# this file is generated via ${url}/blob/$(git log -1 --format='format:%H' HEAD -- "$self")/$self

Maintainers: Valeriy Solovyov <weldpua2008@gmail.com> (@weldpua2008)

EOH


GlobalPWD="$PWD"
levels=$(echo "$GlobalPWD"|tr '/' ' '|wc -w)
for real_file in `find $GlobalPWD/ -name "Dockerfile"`;do
	commit="$(git log -1 --format='format:%H' -- "$real_file" $(awk 'toupper($1) == "COPY" { for (i = 2; i < NF; i++) { print $i } }' "$real_file"))"
	fullVersion="$(basename "$(dirname "$real_file")")"
	if [ "x$fullVersion" = "x" ];then
		continue
	fi
	if [[ " ${ADDED_TAGs[@]} " =~ " ${fullVersion} " ]]; then

		num2=2
		z=$(echo  '([^/]+/){'$(($levels+$num2))'}[^/]+/?$')
		directory=$(grep -oP "$z"  <<< "$real_file")
		newfullVersion="${fullVersion}-$(echo "$directory"|cut -d '/' -f1,2|tr '/' '-')"
#		continue
		if [[ " ${ADDED_TAGs[@]} " =~ " ${newfullVersion} " ]]; then
			unset num2
		else
			TAGs="${newfullVersion}"
			ADDED_TAGs+=("${newfullVersion}")
		fi
	else
		TAGs="${fullVersion}"
		ADDED_TAGs+=("${fullVersion}")
	fi
#	echo "$fullVersion: ${url}@${commit}"
	cd "$(dirname "$(dirname "$real_file")")"
	for soft_link in `find -L  "$PWD/"  -xtype l`;do
		if [ "$fullVersion" = $(echo "$(basename "$(readlink -f "$soft_link")")") ];then
#			echo "$(basename "${soft_link}"): ${url}@${commit}"
			mew_tag="$(basename "${soft_link}")"
#			TAGs="${TAGs}, $(basename "${soft_link}")"

				if [[ " ${ADDED_TAGs[@]} " =~ " ${mew_tag} " ]]; then
					if [ "${mew_tag}" = "latest" ];then
						continue
					fi
					num2=2
					z=$(echo  '([^/]+/){'$(($levels+$num2))'}[^/]+/?$')
					directory=$(grep -oP "$z"  <<< "$real_file")
					newfullVersion="${mew_tag}-$(echo "$directory"|cut -d '/' -f1,2|tr '/' '-')"
#					continue
					if [[ " ${ADDED_TAGs[@]} " =~ " ${newfullVersion} " ]]; then
						continue
					else
						ADDED_TAGs+=("${newfullVersion}")

						TAGs="${TAGs}, ${newfullVersion}"
					fi
				else
#					TAGs="${fullVersion}"

					TAGs="${TAGs}, ${mew_tag}"

					ADDED_TAGs+=("${mew_tag}")
				fi


		fi

	done
#	echo "$(dirname "$real_file")"
num2=2
z=$(echo  '([^/]+/){'$(($levels+$num2))'}[^/]+/?$')
directory=$(grep -oP "$z"  <<< "$real_file")
cat <<-EOE

		Tags: ${TAGs}
		GitRepo: ${url}.git
		GitCommit: ${commit}
		Directory: $(dirname "$directory")

EOE

#	echo "${fullVersion%.*}: ${url}@${commit}"
#	echo "${fullVersion%.*.*}: ${url}@${commit}"
#	echo "latest: ${url}@${commit}"

done