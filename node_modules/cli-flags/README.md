cli-flags
=========

[![CircleCI](https://circleci.com/gh/heroku/cli-flags/tree/master.svg?style=svg)](https://circleci.com/gh/heroku/cli-flags/tree/master)
[![codecov](https://codecov.io/gh/heroku/cli-flags/branch/master/graph/badge.svg)](https://codecov.io/gh/heroku/cli-flags)

CLI flag parser.

Usage:

```js
const CLI = require('cli-flags')

const {flags, args} = CLI.parse({
  flags: {
    'output-file': CLI.flags.string({char: 'o'}),
    force: CLI.flags.boolean({char: 'f'})
  },
  args: [
    {name: 'input', required: true}
  ]
})

if (flags.force) {
  console.log('--force was set')
}

if (flags['output-file']) {
  console.log(`output file is: ${flags['output-file']}`)
}

console.log(`input arg: ${args.input}`)

// $ node example.js -f myinput --output-file=myexample.txt
// --force was set
// output file is: myexample.txt
// input arg: myinput
```
