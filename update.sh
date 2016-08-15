#!/usr/bin/env bash
######################################################
# Generate Dockerfiles
# author: Valeriy Soloviov <weldpua2008@gmail.com
######################################################
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#
EOH

}

#jsonSh="$(curl -fsSL 'https://raw.githubusercontent.com/dominictarr/JSON.sh/ed3f9dd285ebd4183934adb54ea5a2fda6b25a98/JSON.sh')"
allReleaseInfo=$(curl -fsSL "https://downloads.powerdns.com/releases/")
#allVersions=$(echo "$allReleaseInfo"|  grep -Eo 'pdns-[0-9].[0-9].[0-9]'|uniq)

travisEnv=
for version in "${versions[@]}"; do
	minor=$(echo "$version"|cut -d '.' -f1|tr -d " ")
	docker_file_prefix="$minor/$version"

	if [ "x${minor}" = "x"  ]; then
		echo "Can't detect minor version for $version"
		continue
	fi

	for comp in tar.xz tar.bz2 tar.gz; do
		filename=$(echo "$allReleaseInfo"|  grep -Eo 'pdns-'${version}.${comp}|uniq)
		if [ "x$filename" = "x"  ]; then
			continue
		fi
		break
	done
	if [ "x$filename" = "x"  ]; then
		echo "No such file for version: $version"
		exit 126
	fi

	dockerfiles=()
	mkdir -p "$docker_file_prefix"
	{ generated_warning; cat Dockerfile-ubuntu.template; } > "$docker_file_prefix/Dockerfile"



done

