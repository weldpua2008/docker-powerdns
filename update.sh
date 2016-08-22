#!/usr/bin/env bash
######################################################
# Generate Dockerfiles
# author: Valeriy Soloviov <weldpua2008@gmail.com
######################################################
set -e
_ROOT_PATH="$(dirname "$(readlink -f "$BASH_SOURCE")")"
cd "$_ROOT_PATH"
###### VARS
declare -a _SUPPORT_PLATFORMS=('Debian=>jessie stretch wheezy' 'Ubuntu=>12.04 14.04 16.04')
# path to templates of DockerFiles
_DCKRFILE_TMPL_DIR="templates"
_FILENAME_TMPL_DISTRO="%distro%-Dockerfile"
_FILENAME_TMPL_DISTRO_VERSION="%distro%-%version%-Dockerfile"
_FILENAME_TMPL_DISTRO_VERSION_MINOR="%distro%-%version%-%minor%-Dockerfile"
_FILENAME_TMPL_DISTRO_VERSION_MINORMAJOR="%distro%-%version%-%minor%.%major%-Dockerfile"

_PDNS_RELEASES_URL="https://downloads.powerdns.com/releases"
_FILES_FOR_DockerIMG_PATH="files"
_TRAVIS_DOCKERFILES=()
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
#					set -x
					sed -ri '
						s!%%FROM%%!'"$_FROM_VAR"'!;
						s!%%PDNS_VERSION%%!'"$pdns_version"'!;
						s!%%PDNS_FILENAME%%!'"$pdns_fileurl"'!;
					' "$_docker_file_prefix/Dockerfile"
					)
					_TRAVIS_DOCKERFILES+=( "$_docker_file_prefix/Dockerfile" )
					cp -v $_FILES_FOR_DockerIMG_PATH/* "$_docker_file_prefix"
					# fixing permissions
					chmod 755 "$_docker_file_prefix"/*.sh
				fi
		   done
	   count=$(( $count + 1 ))
	done
}

# updates soft links to latest version and minor version
function update_links()
{
	echo "===========> Updating links <================"
#	set -x
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
					for major in $(ls -D);do
						cd $major || continue
						latest_alias="$major"
#						for fullversion in $(ls -D|grep -Eo '^[0-9]{1,}.[0-9]{1,}.[0-9]{1,}$');do
#							major=$(echo "$fullversion"|cut -d '.' -f1|tr -d " ")
						for fullversion in $(ls -D|grep -Eo '^'$major'.[0-9]{1,}.[0-9]{1,}$');do
							minor=$(echo "$fullversion"|cut -d '.' -f2|tr -d " ")
							local __revision_alias="$fullversion"
							if [ "x${major}" = "x" ] || [ "x${minor}" = "x" ] || [ "x${__revision_alias}" = "x" ];then
								continue
							fi

							if [ -L "$major.$minor" ];then
									rm -f "$major.$minor"
							fi
							if [ ! -d "$major.$minor" ] && [ ! -f "$major.$minor" ];then

								# detect best minor+major alias
								for curr_minor_major_revision in $(ls|grep -E '^'$major'.'$minor'.');do
#									echo $curr_minor_major_revision
									if [ $(version2dig $curr_minor_major_revision) -ge $(version2dig $latest_alias) ]; then
										latest_alias="$curr_minor_major_revision"
									fi

									if [ $(version2dig $curr_minor_major_revision) -ge $(version2dig $__revision_alias) ]; then
										__revision_alias="$curr_minor_major_revision"
										if [ "x${__revision_alias}" = "x" ];then
											continue
										fi
									fi
								done

								if [ -L "$major.$minor" ];then
									rm -f "$major.$minor"
								fi
								echo "Creating alias for $_distro/$_distro_version/$major/$major.$minor => $__revision_alias"
								ln -s  "$__revision_alias" "$major.$minor"
							fi

						done
						if [ -d "$latest_alias" ];then
							echo "Generating alias for $_distro/$_distro_version/$major/latest => $latest_alias"
							rm -f "latest" || true
							ln -s "$latest_alias" "latest"
						fi
					done

				fi
	       done
	   count=$(( $count + 1 ))
	done
}

# updates .travis.yml
function update_travis_ci()
{
	echo "===========> Generating .travis.yml <================"
	pwd
	newTravisEnv=
	for dockerfile in "${_TRAVIS_DOCKERFILES[@]}"; do
#		set -x
		dir="${dockerfile%Dockerfile}"
		dir="${dir%/}"
		version=$(basename "$dir")
		variant=$(echo "${dir%/*/*}"|tr '/' '-')
		newTravisEnv+='\n  - VERSION='"$version VARIANT=$variant DockerFile_DIR=$dir"
	done
	set +x
	travisEnv="$newTravisEnv$travisEnv"
	travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
	echo "$travis" > .travis.yml


}

function main()
{
	#jsonSh="$(curl -fsSL 'https://raw.githubusercontent.com/dominictarr/JSON.sh/ed3f9dd285ebd4183934adb54ea5a2fda6b25a98/JSON.sh')"
	allReleaseInfo=$(curl -fsSL "$_PDNS_RELEASES_URL/")
	#allVersions=$(echo "$allReleaseInfo"|  grep -Eo '[0-9]{1,}.[0-9]{1,}.[0-9]{1,}'|uniq)
	echo "===========> Generating DockerFiles <================"
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
	# updating links for
	# 	-	major+minor versions
	#	-	major versions
	update_links
	cd "$_ROOT_PATH"

	update_travis_ci
}

############# main flow

main