# cnmap
Automated network discovery and port scanning script through Nmap and NSE.

![alt text](https://github.com/cheshireca7/cnmap/blob/master/images/cnmap.png?raw=true)

## Usage
- `./cnmap.sh IP`
- `./cnmap.sh CIDR`

## Notes
- Every scan report will be stored at ./log folder
- SNMP and TFTP scripts will be run although UDP ports were reported as closed, just to avoid false negatives.
