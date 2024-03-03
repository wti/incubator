#!/usr/bin/env bash

# errMssg {nnn} message.. # emit message to stderr, optionally emit nnn code
# use `return $(errMssg 2 message...)` to emit message and return code
errMssg() {
	if [[ "SS${1}EE" =~ SS[0-9]+EE ]] ; then
		local -r code=" ($1)"; shift 1
	else 
		local -r code=""
	fi
	echo "# ${FUNCNAME[1]}${code}: ${@}" 1>&2
	[ -n "$code" ] && echo "$code"
	return 0
}

# buildSwiftBook # build TSPL for static site and deploy to local
buildSwiftBook() {
	which xcrun >/dev/null 2>&1 || return $(errMssg 31 No xcrun)
	local -r ghUser="${1:-wti}"
	local -r bsbOut="${FUNCTION[0]}.out"
	local -r sbDir="$HOME/git-apple/swift-book"
	[ -d "$sbDir" ] || return $(errMssg 31 no $sbDir)
  local -r webPath=tspl
  local -r webBase=incubator
  local -r hostBase="--hosting-base-path $webBase/$webPath"
  local -r webDocs="$HOME/git/$webBase/docs" 
  [ -d "$webDocs" ] || return $(errMssg 31 "no $webDocs for publishing")

	pushd "$sbDir" >/dev/null
    set -e
  	[ -n "${DEBUG}" ] && set -vx
  	local -r out="${bsbOut}.TSPL.doccarchive"
  	local -r web="${bsbOut}.out.TSPL.html"
  	if [ -d "${out}" ] ; then
      errMssg "Adopting existing archive: $out"
    else 
  		mkdir -p "${out}"
  		xcrun docc convert -o "${out}" --ide-console-output TSPL.docc
  	fi
  
  	if [ -d "${web}" ] ; then
      errMssg "Adopting existing html: $web"
    else
  		mkdir -p "${web}"
  		xcrun docc process-archive \
  			transform-for-static-hosting \
  			"$out" \
  		 --output-path "${web}" ${hostBase}
  	fi
    [ -n "${DEBUG}" ] && {set -vx} 2>/dev/null
    
    echo "cd \"$sbDir\""
    ls -d "${out}"/* "${web}"/*
  popd >/dev/null
  local -r baseURL="https://${ghUser}.github.io/${webBase}"
	cat<<EOF
# build per https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/generating-documentation-for-hosting-online/
# copying to local $webBase to publish to ${baseURL} 
if [ -d "$webDocs" ] ; then
  if [ -d "$webDocs/${webPath}" ] ; then
    echo "verify overwrite of $webDocs/${webPath}"
  else
    cd "$sbDir"
    cp -rf "$out" "$webDocs/${webPath}"
    echo "cd  $webDocs/"
    echo " Verify on correct branch (web)"
    echo " do git commit and push, and (eventually) see "
    echo " ${baseURL}/${webPath}/documentation/the-swift-programming-language/"
    echo " WARNING: process seems flighty"
  fi
fi
EOF
}

#### start
buildSwiftBook "${@}"

