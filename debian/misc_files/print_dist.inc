print_dist()
{
    (
        . /etc/os-release
        case "$ID" in
            debian) ID=Debian ;;
            devuan) ID=Devuan ;;
            ubuntu) ID=Ubuntu ;;
            linuxmint) ID=Linux\ Mint ;;
        esac
        case "$VERSION_ID" in
            "") echo "$ID $VERSION_CODENAME" ;;
            *) echo "$ID $VERSION_CODENAME/$VERSION_ID" ;;
        esac
    )
}
