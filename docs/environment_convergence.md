# Environment Convergence

The term "environment" as used in this document refers to a directory on the server, such as `/etc/puppetlabs/code/environments/<name>`, containing puppet manifests, hiera data, custom facts, etc.

At the beginning of an agent run, the agent and server negotiate which environment to use. It is important for the agent and server to use the same environment during the run, because the manifest may reference facts that must be downloaded and evaluated on the agent. If they are mismatched, then compilation can fail.

For security reasons, puppet defaults to **server-specified environments**. This means the server always decides which environment to assign to each agent. This is important because we don't want an agent to request a catalog from an arbitrary environment, as the server might include a class containing sensitive data.

However, there are cases during [iterative development](https://puppet.com/docs/pe/latest/environment_based_testing.html) where it is necessary for a trusted user to be able to run the agent against an environment contained in a feature branch. For example, `puppet agent -t --environment <feature>`. If the code works as intended, then it provides confidence that the feature branch code can be merged. We refer to this workflow as an **agent-specified environment**.

## Agent and Server Negotiation

The server decides which environment an agent should use by asking its node terminus to classify the node. Terminus just means there's an implementation of an interface that knows how to perform CRUD operations on `Puppet::Node` objects. The terminus is responsible for returning a node object, including the environment that the node is assigned to.

PE ships with a `classifier` node terminus that communicates with the PE classifier via REST. So by default, PE uses server-specified environments.

However, open source defaults to a `plain` node terminus, which means it falls back to agent-specified environments.

When the agent negotiates with the server, the server may respond in one of the following ways:

  1. Tell the agent to switch to the server-specified environment.
  2. Allow the agent to continue using its current agent-specified environment.
  3. Fail the run due to a classification conflict. Conflicts can arise if the agent is assigned to multiple environments at the same time, as can happen if the agent's facts match multiple rules in the classifier.
  4. Fail the request because the agent's requested environment doesn't exist on the server.

## Convergence

If the agent starts off in the correct environment at the start of its run and it uses that environment for the duration of the run, then the agent and server environments are **synchronized**.

The process of trying to synchronize environments is referred to as **environment convergence**.

## Server-specified environments

When running in a server-specified context, i.e. the server always decides which environment to use, then the agent's run should result in one of the following outcomes (ignoring networking issues, etc):

  1. If the agent's environment is synchronized with the server, then the agent uses that environment for the duration of the run.
  2. If the environments are not synchronized, then the server will attempt to switch the agent to the server-specified environment. The agent will retry its run using the server-specified environment, up to some maximum retry limit.
  3. If the environment does not converge after N retries, then the agent fails the run. This can happen if classification rules cause the environment to flap from environment A to B to A, etc.

There are several reasons why environments may not be synchronized:

1. The agent has never run before or its cache directory was deleted.
2. The agent was configured to use a different environment on the command line or puppet.conf than it used last time.
3. Classification changed on the server.
4. A fact's value changed on the agent and classification is based on the fact.
5. The environment was updated on the server, such as modifying a fact used in classification.
6. The environment was deleted on the server.

In all cases, the server will attempt to switch the agent to a "known good" environment. For example, if agents are configured to use an environment, but it is deleted from the server, then we want those agents to reconverge to a **new** server-specified environment. This self-healing property is important when running agents at scale.

## Agent-specified environments

When running in an agent-specified context, i.e. the server **allows** the agent to decide, then the agent's run may result in one of the following outcomes (again ignoring networking issues):

1. If the environment exists on the server, then the agent will use that for the duration of the run, even if it needs to download facts and plugins from the server.
2. If the environment doesn't exist on the server:
  1. By default, switch to the server-specified environment, typically the value of `Puppet[:environment]` on the server.
  2. Otherwise, if `strict_enviroment_mode` is enabled, then fail the run, because the user wants to strictly use the requested environment.

## Last Used Environment

Prior to 6.25.0 and 7.10.0, the agent used to make a node request at the beginning of the run to determine which environment to start off in. This was changed in [PUP-10216](https://tickets.puppet.com/browse/PUP-10216) so the agent will start off in the environment it used last time. This information is stored in `Puppet[:lastrunfile]`. Doing so eliminates the agent's node request and several requests among server, classifier, puppetdb and postgres. 

The old behavior can be enabled using the `Puppet[:use_last_environment]=false` setting or specifying `--no-use_last_environment` on the command line.

## Flow Diagram

The following flow diagram shows how the agent converges its environment. The green lines trace the happy path:

[![](https://mermaid.ink/img/pako:eNqlVt9v2jAQ_les7LWVRqm0jYdNVUufWlQB3R4CqjznEqw6NrMdWgT93-dfwSHA0IAHuJzv--783XHKKiEig6SXTHjOxBuZYanR-G7CkfmMtH26vPyObmdAXm8xmcHqWQFyVmZ-NGai-PHhw2OQxazHsoL1g8CZc6XWagGne3H3mClYD0xZA1xCOgQl2AKQdSDrCagNsyvwaHgd4KJ_YkazEcgFyD5fUCl4CVyvGjbqv1OlVX21_QBXbu7KdXcYaUmJfjSZGheLTpd6ra0shuSRqhJrMkv7UgqJfhnOAjXIp__gCDkFY0D0PSZaHS3TpX1iVUG5WnISyBsMjvlJKB2aY5T8U4HSaABvrYZFGkfNTUDuKAjmyIwQLwBxU-wLN4K_LDCrtotNwwNyTzVpTB1HznRzLriCVV3MqCIEIINsa-jqsHhTK7BVF9RWV4PvMLjRTTdcZhjZb0xe49gjwU3dlFUSapqYLBZwK7jpgh5ilgYTaYGGNw8tLVtYnz_2e-VNZO063fY07AzU3qDGvYZgjqwu715JZB1L9EBLqlvCuMCYZCzEI-bL4A-Da5zIelFwTw8w-Ap2JnBH6a07uZO6kWF5HOvnLlseNoo9obwIhftuDoRGN8ysPshC5du3dLM4hLmQOjYsKL1ztkmxD9W8S6Oszcm-fRCvPD3M05w3DxiLo3MX59PV-jzPsAa_qb19YFfvpHHwm_mcLVsVHhKpkSpiU_fdSuZ9EZ-OgGfBDiH-wcXcCR72rv9mlJvFuWSAPiOlpXiF3qc87154-_KNZnrWu56_B0evkAC8Db06HXp9OvTr6dBvp0M7Z-jU6ZyBPUPkzhkqX305Hds9Q6vuGVp1_0ur5CIpQZaYZuYNb2W5JomeQQmTpGfMDHJcMT0xL38fJrRyf8x-RrWQSc9tp4sEV1qMzLreOHzUHcWFxGXwfvwFBtGZ8Q)](https://mermaid.live/edit#pako:eNqlVt9v2jAQ_les7LWVRqm0jYdNVUufWlQB3R4CqjznEqw6NrMdWgT93-dfwSHA0IAHuJzv--783XHKKiEig6SXTHjOxBuZYanR-G7CkfmMtH26vPyObmdAXm8xmcHqWQFyVmZ-NGai-PHhw2OQxazHsoL1g8CZc6XWagGne3H3mClYD0xZA1xCOgQl2AKQdSDrCagNsyvwaHgd4KJ_YkazEcgFyD5fUCl4CVyvGjbqv1OlVX21_QBXbu7KdXcYaUmJfjSZGheLTpd6ra0shuSRqhJrMkv7UgqJfhnOAjXIp__gCDkFY0D0PSZaHS3TpX1iVUG5WnISyBsMjvlJKB2aY5T8U4HSaABvrYZFGkfNTUDuKAjmyIwQLwBxU-wLN4K_LDCrtotNwwNyTzVpTB1HznRzLriCVV3MqCIEIINsa-jqsHhTK7BVF9RWV4PvMLjRTTdcZhjZb0xe49gjwU3dlFUSapqYLBZwK7jpgh5ilgYTaYGGNw8tLVtYnz_2e-VNZO063fY07AzU3qDGvYZgjqwu715JZB1L9EBLqlvCuMCYZCzEI-bL4A-Da5zIelFwTw8w-Ap2JnBH6a07uZO6kWF5HOvnLlseNoo9obwIhftuDoRGN8ysPshC5du3dLM4hLmQOjYsKL1ztkmxD9W8S6Oszcm-fRCvPD3M05w3DxiLo3MX59PV-jzPsAa_qb19YFfvpHHwm_mcLVsVHhKpkSpiU_fdSuZ9EZ-OgGfBDiH-wcXcCR72rv9mlJvFuWSAPiOlpXiF3qc87154-_KNZnrWu56_B0evkAC8Db06HXp9OvTr6dBvp0M7Z-jU6ZyBPUPkzhkqX305Hds9Q6vuGVp1_0ur5CIpQZaYZuYNb2W5JomeQQmTpGfMDHJcMT0xL38fJrRyf8x-RrWQSc9tp4sEV1qMzLreOHzUHcWFxGXwfvwFBtGZ8Q)
