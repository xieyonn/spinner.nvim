# Contributing to spinner.nvim

Thank you for your interest in contributing to `spinner.nvim`! We appreciate your help in improving this project.

## TOOLS

You may need install:

- luarocks
- prettier
- shfmt
- doctoc
- busted
- stylua
- luacov

## Tests

- Install `busted` `luacov`

```bash
luarocks install busted
luarocks install luacov
```

Run all tests:

```bash
make test
```

Run tests with coverage analysis:

```bash
make cov
```

## Formatting

Run the formatter before submitting changes:

```bash
make fmt
```

### Docs

Update docs:

```bash
make doc
```

## Pull Request Guidelines

- Keep pull requests focused on a single feature or bug fix
- Provide a clear description of the changes
- Include tests for new functionality
- Update documentation if needed
- Ensure all tests pass
- Follow the project's code style

## Questions?

If you have questions about contributing, feel free to open an issue for discussion.

Thank you for contributing to `spinner.nvim`!
