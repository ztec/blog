---
title: "GraphQL  JIT, is it worth it?"
date: 2025-01-29T00:00:00+02:00
slug: "is-graphql-jit-worth-it"
images: [2025/post/graphql-jit-est-t-il-vraiment-plus-performant/img/cover-en.jpg]
description: "Revisiting the choice of using GraphQL JIT after a few years of real world usage on a GraphQL API"
tags: ["tech", "node.js", "graphql", "performance", "human-helped"]
promotions:
  twitter: https://x.com/DeezerDevs/status/1884558357534507222
  mastodon: https://mamot.fr/deck/@ztec/113911372387577561
  bluesky: https://bsky.app/profile/ztec.fr/post/3lgutyt5roj25
---


## Backstory

A few years ago, I designed and set up a GraphQL server at Deezer. Among all the challenges I faced, one was related to performance. Designing a GraphQL server that is both convenient to use and performant is not an easy task, especially in Node.js.

One of the optimizations we made with [Jimmy Thomas](https://fr.linkedin.com/in/jimmythomasinfo) was to use [GraphQL JIT](https://github.com/zalando-incubator/graphql-jit) instead of the default GraphQL execution engine.
The [README](https://github.com/zalando-incubator/graphql-jit?tab=readme-ov-file#why) claims to improve response time and increase the number of queries that can be executed per second by reducing the CPU time it takes to compute a single query.

## What is GraphQL JIT
GraphQL JIT is a Just-In-Time compiler for GraphQL queries. It is designed to take advantage of [V8](https://en.wikipedia.org/wiki/V8_(JavaScript_engine)) optimizations to increase performance. It is a drop-in replacement for the default execution engine of GraphQL, with a few restrictions.
One of the most important is stated in the project's README:

> All computed properties must have a resolver, and only these can return a Promise.

Depending on how you design your server, this limitation may or may not be an issue.
In my case, it was not an issue at all.

The performance gain claim is pretty impressive: up to 10 times faster than the default execution engine.

## Why we switched

At the time, we conducted extensive tests on the project and used [Gatling](https://en.wikipedia.org/wiki/Gatling_(software)) for load testing. I specifically crafted some reference queries and used them to compare the performance of all the changes made. This way, we could improve response time and admissible load bit by bit. One of the most important changes was the adoption of GraphQL JIT. The performance gain was substantial enough to make it worth the switch at the time.
Unfortunately, all reports and graphs were purged, thanks to Jenkins' cleaning policies.

## Why reconsider it now?

When we conducted the tests and made the switch, the project was barely used. I completely relied on my test queries for benchmarks. Those queries were built to be representative of a theoretical usage, but they were not real queries as no clients of the API existed yet.

Now, the API is live and in use. I have real-world queries to analyze, and I can observe the server's performance in real-time with real clients. 

So, let's revisit this choice and see if it is still the right one.

## Test methodology

Two tests are in order:
- One in production with real customers queries
- One using the old method with Gatling, as before

### Production test
To test the two engines simultaneously, I modified the server's code to randomly start with one engine or the other. When deployed onto the Kubernetes cluster, multiple instances of the service will be started—enough from both engines to gather significant statistics.

The code is quite barbaric but works wonderfully:

```typescript
expressApp.use(
   [...],
   Math.random() > 0.5
       ? createJitGraphqlMiddleware({schema})
       : createJsGraphqlMiddleware(schema),
);
```

Once in production, I will analyze metrics to evaluate the impact of each engine. I will primarily focus on:
- System metrics such as CPU and memory usage
- Node.js system metrics such as [Event Loop Utilization (ELU)](https://nodesource.com/blog/event-loop-utilization-nodejs/), HEAP size, and Garbage Collection
- Response time goals (how much it deviates from the target)
- Average response time and 95th percentile


### Lab tests

For the lab tests, I will use what's already available from my previous tests years ago. I've set up Gatling with a few typical queries. The queries and rate of fire are not exactly the same as before because, over the years, I've tuned them to be more representative of the real world. When I say "more representative," I don't mean they are truly representative. Instead, I've simply adjusted them based on our observations in the field and modified them in a way that makes them closer to the real world. Unfortunately, I have no way of confirming this; it's far from scientific here.

The most notable change is the way scenarios are grouped. Previously, each query had its own rules during the test. Now, I've grouped them into two main categories, representing two typical client profiles:
- **Light users** send small queries. This is standard usage of the API, similar to how any customer would interact with our apps/front-end.
- **Heavy users** make large and complex queries with lots of fields and nested fields. This is typical of a customer using some costly features of our apps or any rogue client trying to abuse the API.

What's important is that the two profiles do not fire queries at the same rate. One fires far more frequently than the other.

The final Gatling scenario looks like this:

```scala
val heavyUser_ConcurentUser = max_reqps/20
val heavyUser_ConcurentRequest = max_reqps/20
val lightUser_ConcurentUser = max_reqps - heavyUser_ConcurentUser
val lightUser_ConcurentRequest = max_reqps - heavyUser_ConcurentRequest


setUp(
   lightUser.inject(
       rampConcurrentUsers(1) to (lightUser_ConcurentUser) during (2 minutes),
       constantConcurrentUsers(lightUser_ConcurentUser) during (duration - 2 minutes)
   ).throttle(reachRps(lightUser_ConcurentRequest) in (duration minutes)),
  
   heavyUser.inject(
       rampConcurrentUsers(1) to (heavyUser_ConcurentUser) during (2 minutes),
       constantConcurrentUsers(heavyUser_ConcurentUser) during (duration - 2 minutes)
   ).throttle(reachRps(heavyUser_ConcurentRequest) in (duration minutes))
).protocols(httpProtocol)
```

The Gatling tests will run on my laptop but will target instances of the server deployed in a development Kubernetes cluster. This cluster is similar to the one in production in form and configuration but not in size. I won't push the cluster to its limits, so I'm not concerned about the results being skewed by the environment.

I will monitor the same metrics as in the production test. This time, I will not consider the results from Gatling itself because I am running the tests from my laptop and cannot trust the response times gathered by Gatling. Moreover, I don't really need them.

## Results
### Production results
#### Response times

One of the metrics I have is the time it takes for the engine to compute a request and produce a response.
It does not include the time it takes to send the response to the client or network delays.

{{< illustration src="img/prod-avg-all.png"
name="Average response time per engine"  
alt="Graph of the average response time per engine"
resize="no" >}}
The average response time shows that the JS engine is slightly faster, but with only a one-millisecond difference, it's not really significant.

{{< illustration src="img/prod-95p-all.png"
name="95th percentile of the response time per engine"  
alt="Graph of the 95th percentile of the response time per engine"
resize="no" >}}

The 95th percentile shows a somewhat greater difference. It is not enormous, but five milliseconds does feel significant.

Regarding response time, we can say, without any doubt, that the `JIT engine’ is not worth it, mathematically speaking. However, we are talking about a five-millisecond difference, so it is not really a big deal either.

#### System metrics (CPU & RAM)

The service is deployed on a Kubernetes cluster. I have access to the cluster metrics and can see how much CPU and RAM are used by the service.

In Kubernetes, we set CPU and RAM reservations. It is a good practice to indicate to the cluster how many resources the pods will need.
For example, we can define that one Node.js process can use up to two CPUs.
The graph then shows how much of these two CPUs are used compared to the reservation.
The same applies to RAM. Of course, the graph shows values for the entire cluster, not just one pod.
```yaml
limits:
 memory: 512Mi
requests:
 memory: 512Mi
 cpu: 2
```
This is an example of a configuration for a pod. This means the pod will have two CPUs and 512Mi of RAM at its disposal.

{{< illustration src="img/prod-system-cpu.png"
name="Percent of the CPU reservation used"  
alt="Percent of the CPU reservation used"
resize="no" >}}

The `js-engine’ uses 2% less CPU than the `JIT-engine.’ It is a consistent difference, but like the response time gain, it is not that significant. Don't get me wrong, when you deploy hundreds or thousands of pods, 2% can mean a lot, but I'm not convinced it does in my case.

{{< illustration src="img/prod-system-RAM.png"
name="Percent of the RAM reservation used"  
alt="Percent of the RAM reservation used"
resize="no" >}}

The RAM usage is a bit more interesting. The `js-engine’ uses ~20% less RAM than the `JIT-engine.’ Here, a 20% difference feels substantial.
#### Node.js metrics

{{< illustration src="img/prod-nodejs-elu.png"
name="Event Loop Utilization min at cluster level, max and average"  
alt="Event Loop Utilization min at cluster level, max and average"
resize="no" >}}

I challenge you to identify when the deployment occurred. The ELU (Event Loop Utilization) did not shift a single bit, even with 50% of the requests being handled by the `js-engine.’ This graph only shows the overall cluster level, as I cannot get metrics for each engine separately. In my opinion, since 50% of the pods use another engine, if the ELU were significantly impacted, we would see it. I will assume that using either `JIT’ or `js’ does not change anything in terms of Event Loop Utilization.

{{< illustration src="img/prod-nodejs-heap-old.png"
name="HEAP old space usage at cluster level, min, max, and average"  
alt="HEAP old space usage at cluster level, min, max, and average"
resize="no" >}}

Monitoring the HEAP shows that the `old’ space seems to have reduced slightly. It is not very obvious in the graph but it is visible in the average. The maximum did not change, but the minimum did. This confirms what we observed earlier with RAM usage.

Other HEAP spaces were not impacted at all, and the same goes for Garbage Collection. They all tell the same story as the ELU metrics. They remain unchanged from before, so I didn't bother screenshotting the graphs.
### Lab results

I ran the Gatling test for each engine in two separate deployments. The tests were run simultaneously. Strictly speaking, they could have impacted one another, but I don't think this effect is significant, as the cluster I was using had enough resources to handle the load. Moreover, the load was not that high, and I kept the request rate well below limits.

#### Response times

{{< illustration src="img/lab-all.png"
name="Average and 95th percentile response time per engine"  
alt="Average and 95th percentile response time per engine"
resize="no" >}}

The results are not favorable for the `js` engine. The difference is substantial. We must remember that this is a lab environment, and response times may differ from those in production. However, we are losing about 50 milliseconds on the 95th percentile and 20 milliseconds on average. These represent slowdowns of approximately 50% and 70%, respectively, compared to the `JIT’ engine.

#### System metrics (CPU & RAM)

{{< illustration src="img/lab-system-all-js.png"
name="Dashboard of System metrics showing CPU and RAM for the js engine"  
alt="Dashboard of System metrics showing CPU and RAM for the js engine"
resize="no" >}}

{{< illustration src="img/lab-system-all-jit.png"
name="Dashboard of System metrics showing CPU and RAM for the JIT engine"  
alt="Dashboard of System metrics showing CPU and RAM for the JIT engine"
resize="no" >}}

The first notable difference is in CPU usage. The `js-engine’ uses 20% more CPU than the `JIT-engine,’ which is significant.

Regarding RAM, the difference is smaller but still present, with only a few percentage points of increased usage for the `js-engine.’

Overall, our synthetic tests indicate that the JIT engine is more efficient than the JS engine.
#### Node.js metrics

{{< illustration src="img/lab-nodejs-all-js.png"
name="Dashboard of Node.js metrics such as ELU, HEAP, and Garbage Collector for the js engine"  
alt="Dashboard of Node.js metrics such as ELU, HEAP, and Garbage Collector for the js engine"
resize="no" >}}

{{< illustration src="img/lab-nodejs-all-jit.png"
name="Dashboard of Node.js metrics such as ELU, HEAP, and Garbage Collector for the JIT engine"  
alt="Dashboard of Node.js metrics such as ELU, HEAP, and Garbage Collector for the JIT engine"
resize="no" >}}

The story remains consistent with the Node.js metrics. The `js engine’ uses more HEAP, more Garbage Collection, and has a higher Event Loop Utilization (ELU). Specifically, the ELU increased from 30% to 50%.


## What is the meaning of all of this?

Okay, things are getting interesting. The production results clearly show a slight advantage for the `js’ engine. This win is small and could, in some cases, be considered negligible. However, it is still a win. On the other hand, the story is entirely different when we look at the lab results. The `JIT’ engine is a clear and substantial winner! Moreover, based solely on the lab results, it is a no-brainer to use the `JIT’ engine.

The lab results were essentially the same as those I had years ago. The `JIT’ engine is faster, more efficient, and requires fewer resources in a lab environment. Back then, I only had those results to inform my decision and naturally chose the `JIT’ engine.

Today, however, the production results complicate the decision:
- The `js’ engine is better or at least as good as the `JIT’ engine in terms of response time, resource usage, and overall performance.
- The complexity introduced by the `JIT’ engine has a cost.
- The `JIT’ engine has certain limitations. We did not encounter these, so they may not be highly relevant in my context.
- The `js’ engine is effectively the "standard."

The question has been raised internally, and there seems to be a consensus that standardization is important enough to justify switching back to the `js’ engine. I tend to agree with this perspective.
## Why does the optimization not show up in production?

The production and lab tests have opposite behaviors that feel counterintuitive. I believe the main reason lies in how we utilize the GraphQL API.

When we began our GraphQL journey, we had a steep learning curve. One of the biggest challenges was designing the schema and envisioning the queries that would be made. We had to rethink everything, moving away from our accustomed REST APIs.

However, as anyone who has worked on an existing system knows (do I hear "legacy"?), we had to consider many existing scenarios and technical limitations. For example, paginated results were not as common back then as they are today. When designing the schema, we aimed to follow the "state of the art" in this regard, but it was not always straightforward or even feasible.

After years of learning and striving towards best practices in GraphQL, we find ourselves in a much better situation than expected. For instance, we initially feared processing massive queries with numerous nested fields. This concern hasn't completely disappeared, but looking at the queries generated by our apps, the reality isn't as daunting as we imagined.

Teams have adapted to the new way of thinking, embracing the limitations and concepts of a GraphQL API. Gradually, they've accepted the need to approach things differently. The quality of our GraphQL queries seems sufficient, indicating that we no longer require the `JIT’ optimizations.

One of the best use cases for `JIT’ appears to be when dealing with complex queries that have many nested fields. We currently don't have that issue, or at least not to a significant extent.

In the future, we may need to reassess this decision based on how we develop our upcoming applications and frontends. But for now, the `js’ engine seems more than adequate.

## Conclusion

A few years ago, I designed a GraphQL server and made several architectural decisions. We implemented some obvious optimizations and conducted tests to verify their effectiveness beyond marketing claims, confirming our choices.

Not all decisions were perfect, and there is much to discuss and critique about the project. However, the choice of the ‘JIT’ engine was a good one at the time.

Today, the context has evolved. We have (enough) real-world clients, and both Node.js and V8 have been improved. Additionally, the standard implementations of GraphQL have benefited from years of community enhancements.

Revisiting old decisions has proven to be insightful, if not beneficial. The ability to test a theory in production easily and without the fear of breaking anything is a luxury. I'm grateful for this opportunity.

Ultimately, we can conclude that the real world always surpasses the lab and its benchmarks. While this may not come as a surprise, it's always a good reminder. If you have the resources and time, take the opportunity to test your hypotheses using real-world data or actual clients whenever possible. For this, it's crucial to maintain healthy development practices that facilitate easy and safe testing and deployment.

In conclusion:

     The `JIT’ engine seems to be worthwhile. However, I would recommend conducting proper tests, if feasible, before fully committing to it. Gains may be small or even imperceptible, depending on your circumstances.

     Anyway, always monitor, metrics are essential!

Thanks for reading me,\
[Bisoux](/page/bisoux) :kissing:

---

Many thanks to [Pauline Munier](https://www.linkedin.com/in/pauline-m-b8703048/) and [Gillian Kelly](https://www.linkedin.com/in/gillian-kelly) for their help in writing this article.
You can also find this [article](https://deezer.io/graphql-jit-is-it-worth-it-64e66f21dbb8), on [Deezer.io](https://deezer.io/graphql-jit-is-it-worth-it-64e66f21dbb8)
