
# LayerCake

LayerCake is a declarative and extensible web framework supporting custom backends, data transformations and rules. It is built on strong conventions *and* adaptable configurations to avoid boilerplate code as much as possible.

Current LayerCake is implemented on Node.JS but there is no reason that it cannot be implemented on other platforms.

## Simplest example

```
config:
    common:
        port: $PORT

http:
    common:
        default:
            driver: express
            groups:
                all:
                    routes:
                        /:
                            GET: get-ping
    dev:
        default:
            groups:
                all:
                    routes:
                        /version:
                            GET: get-metadata
```

When run this will raise an Express based web service responding to `GET /` and, if `$NODE_ENV` is equal to `dev`, `GET /version`.

## Concepts

LayerCake is built on several concepts from which everything else stems:

1. Documentation is the system
2. Code is never generated (it rots too fast)
3. Backward compatibility is maintained through code transformations
4. Orthogonalities of responsibilities can be combined through common protocols

### Orthogonalities

	* Configuration per environment
	* Logging
	* Caching
	* Analytics
	* Tests
	* Error handling
	* Monitoring
	* Data migration
	* Data transformation: encryption, anti-tampering measures, compression
	* Deployment (???) (e.g. each layer-cake is a separate SOA component)

## Protocols

Every extensible and composable system must be based on protocols, on mutual understanding of both consumer and provider of what, when and how information is shared. LayerCake is both extensible and composable and as such needs several core protocols that enable these characteristics.

### Stack execution protocol

TODO

### Store communication protocol

TODO

### JSON API protocol

TODO

### Error protocol

TODO

## Guarantees

TODO
