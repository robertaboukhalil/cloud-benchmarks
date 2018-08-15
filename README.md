# Cloud Benchmarks

### Step 1: Clone repo

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/open?git_repo=https%3A%2F%2Fgithub.com%2Frobertaboukhalil%2Fcloud-benchmarks&page=shell)

### Step 2: Choose benchmark parameters

Modify the `config.json` file with your own configuration parameters, e.g.

```json
{
  "N": 5,
  "gcp": {
    "image": "debian-9",
    "zone": "us-west1-b",
    "machines": [
      { "type": "n1-standard-1" },
      { "type": "n1-standard-8" },
      { "type": "n1-standard-32" },
      { "type": "n1-standard-64" },
      { "type": "n1-standard-96" },
      { "cpu": 2, "mem": 8 }
    ],
    "ssh_key": "~/.ssh/google_compute_engine",
    "scopes": "cloud-platform"
  },
  "tests": [
    {
      "name": "test-case-1",
      "disk": 20,
      "machine": 0
    }
  ]
}
```

Notes:

- `N`: number of times to repeat the benchmark for each test.
- `machines`: array of standard VM types or custom number of CPU and RAM.
- `tests`: array of test cases. In `machine`, use the index from the `machines` key.


### Step 3: Benchmark!

Start the benchmark by launching `./run.sh config.json`
