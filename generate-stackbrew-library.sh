#!/usr/bin/env bash
set -e

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

url='https://github.com/weldpua2008/docker-powerdns'
cat <<-EOH
# this file is generated via ${url}/blob/$(git log -1 --format='format:%H' HEAD -- "$self")/$self

Maintainers: Valeriy Solovyov <weldpua2008@gmail.com> (@weldpua2008)

GitRepo: ${url}.git
EOH


GlobalPWD="$PWD"
levels=$(echo "$GlobalPWD"|tr '/' ' '|wc -w)
for real_file in `find $GlobalPWD/ -name "Dockerfile"`;do
	commit="$(git log -1 --format='format:%H' -- "$real_file" $(awk 'toupper($1) == "COPY" { for (i = 2; i < NF; i++) { print $i } }' "$real_file"))"
	fullVersion="$(basename "$(dirname "$real_file")")"
	if [ "x$fullVersion" = "x" ];then
		continue
	fi
	TAGs="${fullVersion}"
	echo
#	echo "$fullVersion: ${url}@${commit}"
	cd "$(dirname "$(dirname "$real_file")")"
	for soft_link in `find -L  "$PWD/"  -xtype l`;do
		if [ "$fullVersion" = $(echo "$(basename "$(readlink -f "$soft_link")")") ];then
#			echo "$(basename "${soft_link}"): ${url}@${commit}"
			TAGs="${TAGs}, $(basename "${soft_link}")"
		fi

	done
#	echo "$(dirname "$real_file")"
num2=2
z=$(echo  '([^/]+/){'$(($levels+$num2))'}[^/]+/?$')
directory=$(grep -oP "$z"  <<< "$real_file")
cat <<-EOE
		Tags: ${TAGs}
		Directory: $directory
		GitCommit: ${commit}
EOE

#	echo "${fullVersion%.*}: ${url}@${commit}"
#	echo "${fullVersion%.*.*}: ${url}@${commit}"
#	echo "latest: ${url}@${commit}"

done