<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
<!-- [![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![project_license][license-shield]][https://polyformproject.org/licenses/noncommercial/1.0.0]
[![LinkedIn][linkedin-shield]][linkedin-url] -->

<!-- Powered by Michigan -->
<br />
<div align="center">
  <a href="https://innovationpartnerships.umich.edu/">
    <img src="images/stacked.png" alt="Logo" width="15%" >
  </a>
<h3 align="center">Elicit Software</h3>
  <p>Copyright © 2025 The Regents of the University of Michigan</p>
</div>
<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#built-with">Built With</a></li>
    <li><a href="#getting-started">Getting Started</a></li>
    <li><a href="#usage">Usage</a></li>
    <!-- <li><a href="#roadmap">Roadmap</a></li> -->
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project
  <p align="left">
    <a href="https://github.com/elicitsoftware/elicit">Elicit Software</a> was designed and developed by <a href="https://www.michiganmedicine.org/">Michigan Medicine</a>. Pedigree is one module build to display family pedigree images for the <a href="https://github.com/elicitsoftware/FHHS">Family Health History Survey</a> project. It is a simple wrapper using Plumber and Docker to convienently package the Kinship2 package.
  </p>

<div align="center"><image src="images/sample_pedigree.svg" height=600></div>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With
[![Rplumber][Rplumber.io]][Rplumber-url]
[![R][R.org]][R-url]
[![Docker][Docker.com]][Docker-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started
This application is designed to run in a container.

### Running the Container

Start the Docker container with:

```sh
docker run -p 8000:8000 --name pedigree elicitsoftware/pedigree:1.0.0-alpha.1
```

### Submitting a Request

To generate a pedigree SVG, post a request using a sample file (e.g., `ped1.txt`):

```sh
curl -X POST -F "ped=@/full-path-to-directory/ped1.txt" http://localhost:8000/svg
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>
<!-- ROADMAP
## Roadmap
- [ ] Feature 1
- [ ] Feature 2
- [ ] Feature 3
    - [ ] Nested Feature
 -->

See the [open issues](https://github.com/ElicitSoftware/Elicit/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License
Released under the MIT License with in the hope it will be usefull to others.

See `LICENSE.md` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contact

Matthew Demerath – m.demerath@elicitsoftware.com

Project Link: [https://github.com/ElicitSoftware/Pedigree](https://github.com/ElicitSoftware/Pedigree)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/ElicitSoftware/Elicit.svg?style=for-the-badge
[contributors-url]: https://github.com/ElicitSoftware/Elicit/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/ElicitSoftware/Elicit.svg?style=for-the-badge
[forks-url]: https://github.com/ElicitSoftware/Elicit/network/members
[stars-shield]: https://img.shields.io/github/stars/ElicitSoftware/Elicit.svg?style=for-the-badge
[stars-url]: https://github.com/ElicitSoftware/Elicit/stargazers
[issues-shield]: https://img.shields.io/github/issues/ElicitSoftware/Elicit.svg?style=for-the-badge
[issues-url]: https://github.com/ElicitSoftware/Elicit/issues
[license-shield]: https://img.shields.io/github/license/ElicitSoftware/Elicit.svg?style=for-the-badge
[license-url]: https://github.com/ElicitSoftware/Elicit/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/linkedin_username
[product-screenshot]: images/screenshot.png
[Quarkus.io]: https://img.shields.io/badge/quarkus-000000?style=for-the-badge&logo=quarkus&logoColor=white
[Quarkus-url]: https://quarkus.io/
[Vaadin.com]: https://img.shields.io/badge/Vaadin-20232A?style=for-the-badge&logo=vaadin&logoColor=61DAFB
[Vaadin-url]: https://vaadin.com/
[Postgresql.com]: https://img.shields.io/badge/postgresql-white?style=for-the-badge&logo=postgresql&logoColor=blue
[Postgresql-url]: https://postgresql.org/
[Docker.com]: https://img.shields.io/badge/docker-257bd6?style=for-the-badge&logo=docker&logoColor=white
[Docker-url]: https://docker.com
[Java]: https://img.shields.io/badge/Java-3a75b0?style=for-the-badge&logo=openjdk&logoColor=white
[Java-url]: https://dev.java/
[Maven.org]:https://img.shields.io/badge/MAVEN-000000?style=for-the-badge&logo=apachemaven&logoColor=blue
[Maven-url]: https://maven.apache.org/
[R.org]: https://img.shields.io/badge/R-r--project.org-blue?style=flat&labelColor=white&logo=r&logoColor=blue
[R-url]: https://www.r-project.org/
[Rplumber.io]: https://img.shields.io/badge/Plumber%20--%20lightblue
[Rplumber-url]: https://www.rplumber.io/