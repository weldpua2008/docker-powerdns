#!/usr/bin/env bash
######################################################
# Generate Dockerfiles
# author: Valeriy Soloviov <weldpua2008@gmail.com
######################################################
set -e
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
###### VARS
declare -a _SUPPORT_PLATFORMS=('Debian=>jessie stretch wheezy' 'Ubuntu=>12.04 14.04 16.04')
# path to templates of DockerFiles
_DCKRFILE_TMPL_DIR="templates"
_FILENAME_TMPL_DISTRO="%distro%-Dockerfile"
_FILENAME_TMPL_DISTRO_VERSION="%distro%-%version%-Dockerfile"
_PDNS_RELEASES_URL="https://downloads.powerdns.com/releases"
_FILES_FOR_DockerIMG_PATH="files"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

###### VARS


generated_warning() {
	cat <<-EOH
		FROM %%FROM%%
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#
EOH

}
function version2dig() {
	echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}


function generate_dockerfiles_for_distros()
{
	local pdns_fileurl="${1:-}"
	local pdns_version="${2:-}"
	local _DOCKERFILE_TMPL=""
	local _distrofilename_from_tmpl=""
	local _distroversionfilename_from_tmpl=""
	minor=$(echo "$pdns_version"|cut -d '.' -f1|tr -d " ")

	local count=0
	while [ "x${_SUPPORT_PLATFORMS[count]}" != "x" ]

	do

	   _distro=$(echo ${_SUPPORT_PLATFORMS[count]} |grep -oP '^\K.*(?=\=>)'|tr "[:upper:]" "[:lower:]")
	   _distro_versions=$(echo ${_SUPPORT_PLATFORMS[count]} | grep -oP '(?=\=>)..\K.*$')

	   for _distro_version in $_distro_versions
	       do
				_distrofilename_from_tmpl=$(echo $_FILENAME_TMPL_DISTRO| sed "s/%distro%/$_distro/g")
				_distroversionfilename_from_tmpl=$(echo $_FILENAME_TMPL_DISTRO_VERSION|sed "s/%distro%/$_distro/g;s/%version%/$_distro_version/g")
				_FROM_VAR="$_distro:$_distro_version"
				# detect template
				if  [ -f "$_DCKRFILE_TMPL_DIR/$_distroversionfilename_from_tmpl" ] || [ -L "$_DCKRFILE_TMPL_DIR/$_distroversionfilename_from_tmpl" ];then
					_DOCKERFILE_TMPL="$_DCKRFILE_TMPL_DIR/$_distroversionfilename_from_tmpl"
				elif [ -f "$_DCKRFILE_TMPL_DIR/$_distrofilename_from_tmpl" ] || [ -L "$_DCKRFILE_TMPL_DIR/$_distrofilename_from_tmpl" ];then
					_DOCKERFILE_TMPL="$_DCKRFILE_TMPL_DIR/$_distrofilename_from_tmpl"
				fi

				if [ "x$_DOCKERFILE_TMPL" != "x" ];then
					echo "Generating $minor/$pdns_version/Dockerfile for $_distro:$_distro_version"
					_docker_file_prefix="$_distro/$_distro_version/$minor/$pdns_version"
					mkdir -p "$_docker_file_prefix"
					{ generated_warning; cat $_DOCKERFILE_TMPL; } > "$_docker_file_prefix/Dockerfile"
					(
					set -x
					sed -ri '
						s!%%FROM%%!'"$_FROM_VAR"'!;
						s!%%PDNS_VERSION%%!'"$pdns_version"'!;
						s!%%PDNS_FILENAME%%!'"$pdns_fileurl"'!;
					' "$_docker_file_prefix/Dockerfile"
					)
					cp -v $_FILES_FOR_DockerIMG_PATH/* "$_docker_file_prefix"
				fi
		   done
	   count=$(( $count + 1 ))
	done
}

# updates soft links to latest version and minor version
function update_links()
{

	local _rootpath="$PWD"
	local count=0
	while [ "x${_SUPPORT_PLATFORMS[count]}" != "x" ]

	do

	   _distro=$(echo ${_SUPPORT_PLATFORMS[count]} |grep -oP '^\K.*(?=\=>)'|tr "[:upper:]" "[:lower:]")
	   _distro_versions=$(echo ${_SUPPORT_PLATFORMS[count]} | grep -oP '(?=\=>)..\K.*$')

	   for _distro_version in $_distro_versions
	       do
	       		local __distro_wp="$_rootpath/$_distro/$_distro_version"
	       		if [ -d "$__distro_wp" ];then
					cd "$__distro_wp"
					for fullversion in $(ls -D|grep -Eo '[0-9]{1,}.[0-9]{1,}.[0-9]{1,}');do
						minor=$(echo "$fullversion"|cut -d '.' -f1|tr -d " ")
						major=$(echo "$fullversion"|cut -d '.' -f2|tr -d " ")
					done


				fi
	       done
	   count=$(( $count + 1 ))
	done
}

function main()
{
	#jsonSh="$(curl -fsSL 'https://raw.githubusercontent.com/dominictarr/JSON.sh/ed3f9dd285ebd4183934adb54ea5a2fda6b25a98/JSON.sh')"
	allReleaseInfo=$(curl -fsSL "$_PDNS_RELEASES_URL/")
	#allVersions=$(echo "$allReleaseInfo"|  grep -Eo '[0-9]{1,}.[0-9]{1,}.[0-9]{1,}'|uniq)

	travisEnv=
	for version in "${versions[@]}"; do
		minor=$(echo "$version"|cut -d '.' -f1|tr -d " ")

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
	#		exit 126
			continue
		fi

		generate_dockerfiles_for_distros "$_PDNS_RELEASES_URL/$filename" "$version"





	done
}

############# main flow

main