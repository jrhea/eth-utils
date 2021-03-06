#!/bin/bash

char_to_hex() {
    printf  "%02x" "'${1}"
}

char_to_dec() {
    printf  "%d" "'${1}"
}

str_to_hex() {
    for ((i=0;i<${#1};i++));do printf "$(char_to_hex "${1:$i:1}")";done
}

dec_to_hex() {
    printf -v num "%x" "$1"
    if [ "$(( (${#num}+1)/2 ))" -eq "$(( (${#num})/2 ))" ]
    then
        printf "$num"
    else
        printf 0"$num"
    fi
}

hex_to_dec() {
    printf  "%d" "$1"
}

# doesn't pad with 0s
dec_to_bin() {
    local n bit
    for (( n=$1 ; n>0 ; n >>= 1 )); do  bit="$(( n&1 ))$bit"; done
    printf "%s" "$bit" 
}

rlp_encode_len() {
    local length=$1
    local offset
    offset=$(hex_to_dec "$2")
    if [ "$length" -lt 56 ]
    then
        printf "$(dec_to_hex $((length + offset)))"
    elif [ "$length" -lt $((2**63 - 1)) ] # TODO: this should be 2^64, but bash overflows at 2^63
    then
        local length_binary length_bytes
        length_binary=$(dec_to_bin "$length")
        # Because dec_to_bin() doesn't pad with zeros we ensure that truncating arithmetic rounds 
        # up by adding (denom-1) to the numerator.
        length_bytes=$(( (${#length_binary}+7)/8 ))
        # 128 (0x80) + 55 (0x37) = 183 (0xb7) + numBytes(string length)
        printf "$(dec_to_hex $(( offset + 55 + length_bytes )))$(dec_to_hex "$length")"
    else
        exit 1
    fi
    
}

rlp_encode_str() {
    local input=$1
    local length=$2
    if [ "$length" -eq 1 ] && [ "$(char_to_dec "$input")" -lt 128 ]
    then
        printf "$(char_to_hex "$input")"
    else

        printf "$(rlp_encode_len "$length" 0x80)$(str_to_hex "$input")"
    fi
}

rlp_encode_int() {
    local input=$1
    local input_hex length
    input_hex=$(dec_to_hex "$input")
    length=$(( (${#input_hex}+1)/2 ))
    if [ "$length" -eq 1 ] && [ "$input" -lt 128 ]
    then
        printf "${input_hex//00/80}" #If input is non-value 0x00, RLP encoding is 0x80
    else
        printf "$(rlp_encode_len $length 0x80)$input_hex"
    fi
}

rlp_encode_list() {
    local input=$1
    local count=0
    local array=()

    # Search for a delimiter not surrounded in brackets
    for (( i=0; i<${#input}; i++ ));
    do
        if [ "${input:$i:1}" == "[" ]
        then
            ((count=count + 1))
        elif [ "${input:$i:1}" == "]" ]
        then
            ((count=count - 1))
        elif [ "${input:$i:1}" == "," ] && [ $count -eq 0 ]
        then
            # replace the character in the ith position with a new delimiter that we can split on 
            input=$(printf "$input" | sed s/./\|/$((i + 1)))
        fi
    done

    IFS='|' read -r -a items <<< "$input"
    for item in "${items[@]}"; do
        array+=("$(rlp_encode "$item")")
    done
    # flatten array into result
    printf -v result '%s' "${array[@]}" # TODO: not a fan of using the extra variable here
    # $(( (${#result}+1)/2 )) count bytes
    printf "$(rlp_encode_len $(( (${#result}+1)/2 )) 0xc0)${result[*]}" 
}

rlp_encode() {
    local input=$1
    local length=${#input}
    if [ "${input:0:1}" == "[" ] && [ "${input:$((length-1)):1}" == "]" ]
    then
        # remove outer brackets
        rlp_encode_list "${input:1:$((length-2))}"
    elif [ "$input" -eq "$input" ] 2> /dev/null # True if $input is algebraically equal
    then
        rlp_encode_int "$input" "$length"
    else
        rlp_encode_str "$input" "$length"
    fi
}