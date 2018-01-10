# Company Irony C Headers

[![MELPA](http://melpa.org/packages/company-irony-c-headers-badge.svg)](http://melpa.org/#/company-irony-c-headers)

This package provides a [company-mode](https://github.com/company-mode/company-mode) backend for C/C++ header files that works with [irony-mode](https://github.com/Sarcasm/irony-mode).

This package is meant to be complementary to [company-irony](https://github.com/Sarcasm/company-irony) by offering completion suggestions to header files.

## Installation

The recommended way to install `company-irony-c-headers` and its dependencies is through a package manager:

* Using [MELPA](http://melpa.org/)

  ```
  M-x package-install RET company-irony-c-headers RET
  ```

## Usage

It must be loaded after [irony-mode](https://github.com/Sarcasm/irony-mode), while the backend should be grouped with [company-irony](https://github.com/Sarcasm/company-irony), and before it.

Put the following code in your initialization script:

```elisp
(require 'company-irony-c-headers)
;; Load with `irony-mode` as a grouped backend
(eval-after-load 'company
  '(add-to-list
    'company-backends '(company-irony-c-headers company-irony)))
```

Sometimes when the compiler options change, you need to manually reload header completion cache by invoking `company-irony-c-headers-reload-compiler-output`.
