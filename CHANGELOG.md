## v2.0.0

This release introduces several features and breaks compatibility with 1.x. There is now a struct for the UART and SPI chips that holds the relevant information for each. start_link should now be called with the struct. start_link will alias the process with the atom given in the name key of the struct, so it's possible to start more than one chip process at one time now.

When calling any of the public functions on the SubgRfspy module, the first parameter is the UART or SPI struct that was used to call start_link. This allows the SubgRfspy module to use the name key of the struct to communicate with the process, and also allows upstream libraries to more easily define a protocol for the chip functions using the structs.

Additionally, a new chip_present? function has been added to UART and SPI that will attempt to detect whether the chip is responding using the given struct's pin and device configuration.

In some ways the library has gotten more complex because of these changes, but it solves several longstanding problems with supporting different kinds of serial devices and chips, and this should pave the way to making some simplifications in the design for developers using this package as the simplifications become clearer.


## v1.0.0

This release marks the feature complete, minimum viable state of the package. In addition to UART, SPI is now supported.

## v0.9.0

This is an initial release of the package, containing the following:

* Support for communication with a subg_rfspy chip via a UART and the Nerves.UART
* Support for recording UART communication to a csv file for analysis and playback in tests
