#!/bin/env bash

### '' is (not) found without verify
# => add verify at the beginning 
# '' is found
# '' is found in ''
# '' is found in '' at least '' times
# '' is not found
# '' is not found in ''
found="^(?=.*'.*' is( not | )found)(?!.*verify).*"

### create json of
# => create json escaped string of ''
# create json of ''
json="create( the | )json of '.*'"

### insert ''
# => move '' in ''
# insert '' in ''
ins="insert( the | )'.*' in"

### hash to point '' of each object in
# => use foreach with `create hash to point '' of ''`
# create hash to point '' of each object in ''
htp="hash to point '.*' of each object in"

### Rule caller restroom-mw
# => Rule unknown ignore
# Rule caller restroom-mw
rcr="^[rR]ule caller restroom-mw"

### number '' is without verify
# => add verify at the beginning 
# number '' is less than ''
# number '' is less or equal than ''
# number '' is more than ''
# number '' is more or equal than ''
num="^(?=.*number '.*' is)(?!.*verify).*"

### length of
# => use "size" instead of "length"
# create legnth of ''
# verify length of '' is less than ''
# verify length of '' is less or equal than ''
# verify length of '' is more than ''
# verify length of '' is more or equal than ''
len="length of '.*'"

### elements in '' are without verify
# => add verify at the beginning 
# elements in '' are equal
# elements in '' are not equal
el="^(?=.*elements in '.*' are)(?!.*verify).*"

### petition signature is without verify
# => add verify at the beginning 
# petition signature is not a duplicate
# petition signature is just one more
pet="^(?=.*petition signature is)(?!.*verify).*"

### check reflow signature
# => use "verify" instead of "size" 
# check reflow siganture fingerprint is new
ref="check reflow signature"

### copy
# => use "from" instead of "in" (for double in use pickup statement)
# copy the '' in '' to ''
# create the copy of '' in ''
# create the copy of '' in '' in ''
# create the copy of last element in ''
# create the copy of element '' in array ''
cp="copy( the | )'.*' in '.*' to '.*'|create( the | )copy of .* in"

deprecated_statements="$found|$json|$ins|$htp|$rcr|$num|$len|$el|$pet|$ref|$cp"
export deprecated_statements
parser() {
    if ( $2 ); then line=$(echo $1 | sed -e "0,/ a / s/ a / /" -e "0,/ an / s/ an / /"); fi 
    line=$(echo $line |sed -e "s/ I / /" \
			-e "s/ the / /g" \
			-e "s/ have / /" \
			-e "s/ known as / /" \
			-e "s/^[rR]ule //" \
			-e "s/^[wW]hen //" \
			-e "s/^[tT]hen //" \
			-e "s/^[gG]iven //" \
			-e "s/^[iI]f //" \
			-e "s/^[eE]nd[iI]f//" \
			-e "s/^[fF]oreach //" \
			-e "s/^[eE]nd[fF]oreach//" \
			-e "s/^[aA]nd //" \
			-e "s/^that / /" \
			-e "s/^an /a /" \
			-e "s/ valid / /" \
			-e "s/ all / /" \
			-e "s/ inside / in /" \
			-e "s/'[^']*'/\'\'/g" \
			-e "s/  */ /g" \
			-e "s/^ //" \
			-e "/\r$/d" \
			-e "/^\s*$/d"
	)
    echo $line
}
export -f parser

ordered_statements() {
    found_invalid=false
    if [ "$(cat $1 | grep -E '^[rR]ule caller restroom-mw|^[rR]ule unknown ignore')" != "" ]; then
	valid=false
	given=false
	then=false
	while read line; do
	    echo $line | grep  -q "^[gG]iven" && given=true && then=false
	    echo $line | grep  -q -E "^[iI]f|^[fF]oreach|^[wW]hen" && given=false && then=false
	    echo $line | grep  -q "^[tT]hen" && given=false && then=true
	    l=$(parser "$line" $given)
	    if [ "$l" == "" ] || [ "$(echo $line | grep -E "^#|^[rR]ule|^[sS]cenario")" != "" ]; then
		continue
	    fi
	    if $given; then
		if ( ! $valid ) || [ "$(grep -x "$l" zen_statements.yml)" != "" ]; then
		    grep -x -q "$l" zen_statements.yml && valid=true || valid=false 
		else
		    grep -x -q "$l" zen_statements.yml && valid=true || valid=false
		    echo "invalid statement in given: $line"
		    found_invalid=true
		fi
	    elif $then; then
		if ( $valid ) || [ "$(grep -x "$l" zen_statements.yml)" == "" ]; then
		    grep -x -q "$l" zen_statements.yml && valid=true || valid=false
		else
		    grep -x -q "$l" zen_statements.yml && valid=true || valid=false
		    echo "invalid statement in then: $line"
		    found_invalid=true
		fi
	    else
		if [ "$(grep -x "$l" zen_statements.yml)" == "" ]; then
		    echo "invalid statement: $line"
		    found_invalid=true
		else
		    valid=true
		fi
	    fi
	    
	done <$1
    fi
    dep=$(cat $1 | grep -E "$deprecated_statements" \
	      | grep "^[^#]" \
	      | sed "s/^/deprecated statement: /g")
    if [ "$dep" != "" ]; then
	echo "${dep}"
    fi
    if ( $found_invalid ) || [ "$dep" != "" ]; then
	echo $2
	echo "------------------------"
    fi
}
export -f ordered_statements

# handle chains in a better way by separating contracts
contract_parser() {
    if [ ${1##*.} == "yml" ]; then
	tmp=$(mktemp)
	IFS=$'"\n'
	for i in $(yq -o=j '.blocks.*.zenContent' $1 2>/dev/null); do
	    if [ "$i" != "" ] && [ "$i" != "null" ]; then
		printf "$i" > $tmp
		ordered_statements $tmp $1
	    fi
	done
	rm $tmp
    else
	ordered_statements $1 $1
    fi
}
export -f contract_parser

find $1 -type f \( -name '*.yml' -o -name '*.zen' \) \
     -exec bash -c 'contract_parser "$@"' bash {} \; \
