# Tilia driven todo app (TypeScript version)

This application is a simple demo built with [Tilia](https://github.com/tiliajs/tilia) and leveraging the hexagonal architecture.

## domain/feature (adaptors / implementation / use cases)

The feature folder contains implementations of the features defined in the interfaces.

## domain/interface (ports)

This contains the interfaces for the different features (aka "use cases") of the application.

## domain/model (types)

The files in the model folder define the shape of the data that the domain code uses such as what a Todo is.

## domain/repo (persistence layer, drivers)

This contains data source and other dependencies that are required to run the domain code.

# Todos feature

The feature is organized into 3 folders:

- actions: contains the actions that are triggered by the user
- computed: contains the computed state
- observers: contains the observers that are triggered when the state changes

The `todos.spec.ts` file contains the tests for the todos feature.

# Context

The context is used to connect the different features to communicate with each other in an FRP-like manner. All object created by the same `connect` function share the same observing context and can be observed in `computed` or `observe` callbacks.

During testing, we create a separate context for each test so that these can run in parallel.
