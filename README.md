# LE-TLSA

Correctly Add/Update your TLSA records

## Getting Started

Copy the tlsa-updater.sh script to your machine, edit the variables, and setup letsencrypt and cron

### Prerequisites

This script assumes a few things for now:

```
-> you already have letsencrypt setup and configured
-> your TLSA records are encased between ;tlsa and ;aslt tags in the zonefile
-> zonefiles are named domain.ext
-> you use bind (and use inline-signing, there is no dnssec being done in this file)
-> your machine uses systemd (systemctl) to reload daemons
-> you know (somewhat) what you're doing (because at this stage, there is almost no error checking in the script)
```

## Usage

Preferably: after letsencrypt (using renew-hook from letsencrypt) and daily from cron (tlsa-updater.sh --update)

Possibly: by setting and uncommenting "RENEWED_DOMAINS" to manually update a zone (will become an option someday)

## Authors

* **Bjorn Peeters** - *Initial work* - [ThuTex](https://github.com/ThuTex)

## License

This project is licensed under the GNU GPLv3 License - see the [LICENSE.md](LICENSE.md) file for details
