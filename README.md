CS 6250 CDN Tutorial Extra Credit Extensions/Demos for Summer 2026

Note as taken from the BGP Measurement Project:
Georgia Tech asserts copyright ownership of this template and all derivative
works, including solutions to the projects assigned in this course. Students
and other users of this template code are advised not to share it with others
or to make it available on publicly viewable websites including repositories
such as GitHub and GitLab. This copyright statement should not be removed
or edited. Removing it will be considered an academic integrity issue.

We do grant permission to share solutions privately with non-students such
as potential employers as long as this header remains in full. However,
sharing with other current or future students or using a medium to share
where the code is widely available on the internet is prohibited and
subject to being investigated as a GT honor code violation.
Please respect the intellectual ownership of the course materials
(including exam keys, project requirements, etc.) and do not distribute them
to anyone not enrolled in the class. Use of any previous semester course
materials, such as tests, quizzes, homework, projects, videos, and any other
coursework, is prohibited in this course.

This assignment was required to be a publicly viewed GitHub repository that
will be public for the short duration required for it to viewed and graded.
After which it will shortly be made private.

# Overview

This github repository is an extension of the Build BuzzStream CDN tutorial,
specifically Option 1 - Multi-region CDN topology. All code builds from the
functionality provided in the Step 5: Resilience with Stale Cache and Failover
Goal part of the tutorial.

The required prerequisites are outlined in Step 0 (accessible to all GT Tech OMSCS
students and staff). They are Docker Engine, Docker Compose v2, curl, and A POSIX-ish shell.

The topology for this extension is built upon running docker compose up in the ternminal.
In this extension, the client sends normal traffic to the load balancer on host port 18080.
The load balancer routes requests to either region (east or west, east by default) based
upon the X-Viewer-Region header. Each region uses a consistent hash on URI to either edge (0 or 1).
All edges prefer Origin A on host port 18091, but they can fall back to Origin B on host port 18092. 


                                   +-->   East Region     +--> Edge East 0 --+ 
                                   |    (consistent hash) |     18082        |
                                   |                      +--> Edge East 1 --+-->  Origin A (primary :18091)
Client ---> Regional Load Balancer |                            18084        |
              (:18080)             +-->   West Region     +--> Edge West 0 --+~ ~> Origin B (backup :18092)
                                   |    (consistent hash) |     18081        |
                                   |                      +--> Edge West 1 --+
                                                                18083

All modifications are indicated with comments and are present in the docker-compose.yaml
and nginx.loadbalancer.conf. The compose stack was extended to include fake geographic
regions while the number of edges was doubled. A response header was added to visually
indicate which region was routed to. Cahce locality was maintained while regional separation
was enforced. Should Origin A be unavailable (stop) the backup Origin B is utilized. The 
baseline hashing was maintained to ensure consistent routing within regions.

# Run It

Clone the repository and navigate to the folder. From the project folder:

docker compose up

In another terminal:

curl -i http://localhost:18080/videos/news.mp4

Become familiar with the displayed signals. Note the lack of "X-Viewer-Region" as nothing was provided. However, note that it was routed through "X-CDN-Node: edge-east-0".

curl -i -H 'X-Viewer-region: west' http://localhost:18080/videos/news.mp4
sleep 3
curl -i -H 'X-Viewer-region: west' http://localhost:18080/videos/news.mp4

Now I will draw your attention to the presence of "X-Viewer-Region: west" indicating that traffic was correctly routed to the west region. Additionally we see the consistent hashing working as both were routed through the same "X-CDN-Node: edge-west-1". We also learn about the "X-Cache-Status". Note that the first curl received a "MISS" and the second a "HIT". This shows that the content "/videos/news.mp4" was cached and you can see this through the "generated_at" which should match the "Date" of the first curl.

docker compose down

Scenario 1: A West Request and an East Request for the same URL Routing Differently

From the project folder:

docker compose up

In another terminal:

curl -i -H 'X-Viewer-region: west' http://localhost:18080/videos/news.mp4
sleep 3
curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/news.mp4

Notice two things, the first being how they routed differently (X-CDN-Node of edge-west-1 and edge-east-0 respectively) and that they each missed indicating that traffic routed west does not cache for the east.

docker compose down

Scenario 2: Repeated West Requests Becoming MISS then HIT

docker compose up

In another terminal run Example 1:

curl -i -H 'X-Viewer-region: west' http://localhost:18080/videos/news.mp4
sleep 3
curl -i -H 'X-Viewer-region: west' http://localhost:18080/videos/news.mp4

Notice the continued consistent hashing leading to routing to the same west edge node along with how the original curl results in a MISS and the second resulting in a HIT. Let's run it again with a different content example, Example 2.

curl -i -H 'X-Viewer-region: west' http://localhost:18080/videos/viral_news.mp4
sleep 3
curl -i -H 'X-Viewer-region: west' http://localhost:18080/videos/viral_news.mp4

We still see consistent hashing, the first MISS and second HIT, and this time we also see the other west edge node utilized.

docker compose down

Scenario 3: Repeated East Requests Becoming MISS then HIT on the East Side

docker compose up

In another terminal run Example 1:

curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/news.mp4
sleep 3
curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/news.mp4

Then, Example 2

curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/viral_news.mp4
sleep 3
curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/viral_news.mp4

Note consistent hashing, MISS then HIT, and that the east /videos/news.mp4 tracks to node 1 and /videos/viral_news.mp4 tracks to node 0.

docker compose down

Scenario 4: One Resilience or Traffic Scenario, proven with status codes, latency, X-Cache-Status, X-CDN-Node, or X-Upstream-Addr

docker compose up

In another terminal:

curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/viral_news.mp4

Note "X-Origin-Server: origin-a". Then run:

docker compose stop origin-a

Followed by:

curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/viral_news.mp4

Note "X-Origin-Server: origin-b".

docker compose down

Scenario 5: Two Edges per Region and Use Consistent Hashing Inside Each Region

docker compose up

In another terminal:

curl -i -H 'X-Viewer-region: east' http://localhost:18080/article/news.pdf
curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/viral_news.mp4
curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/news.mp4
curl -i -H 'X-Viewer-region: east' http://localhost:18080/videos/viral_news.mp4

Note that "X-CDN-Node" should be edge-east-1 for all but "/videos/news.mp4" and consistent when recalling the same content.
