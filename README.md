

# Getting started

Most of the works in this repository, especially the `R` scripts, should
be directly reproducible. You’ll need
[`git`](https://git-scm.com/downloads),
[`R`](https://www.r-project.org/),
[`quarto`](https://quarto.org/docs/download/), and more conveniently
[RStudio IDE](https://posit.co/downloads/) installed and running well in
your system. You simply need to fork/clone this repository using RStudio
by following [this tutorial, start right away from
`Step 2`](https://book.cds101.com/using-rstudio-server-to-clone-a-github-repo-as-a-new-project.html#step---2).
Using terminal in linux/MacOS, you can issue the following command:

``` bash
quarto tools install tinytex
```

This command will install `tinytex` in your path, which is required to
compile quarto documents as latex/pdf. Afterwards, in your RStudio
command line, you can copy paste the following code to setup your
working directory:

``` r
install.packages("renv") # Only need to run this step if `renv` is not installed
```

This step will install `renv` package, which will help you set up the
`R` environment. Please note that `renv` helps tracking, versioning, and
updating packages I used throughout the analysis.

``` r
renv::restore()
```

This step will read `renv.lock` file and install required packages to
your local machine. When all packages loaded properly (make sure there’s
no error at all), you *have to* restart your R session. At this point,
you need to export the data as `data.csv` and place it within the
`data/raw` directory. The directory structure *must* look like this:

``` bash
data
├── ...
├── raw
│   ├── data.csv
│   └── gbd.csv
└── ...
```

Then, you should be able to proceed with:

``` r
targets::tar_make()
```

This step will read `_targets.R` file, where I systematically draft all
of the analysis steps. Once it’s done running, you will find the
rendered document (either in `html` or `pdf`) inside the `draft`
directory.

# What’s this all about?

This is the functional pipeline for conducting statistical analysis. The
complete flow can be viewed in the following `mermaid` diagram:

- The project is out-of-sync – use `renv::status()` for details.

``` mermaid
graph LR
  style Legend fill:#FFFFFF00,stroke:#000000;
  style Graph fill:#FFFFFF00,stroke:#000000;
  subgraph Legend
    direction LR
    xf1522833a4d242c5([""Up to date""]):::uptodate --- xb6630624a7b3aa0f([""Dispatched""]):::dispatched
    xb6630624a7b3aa0f([""Dispatched""]):::dispatched --- xd03d7c7dd2ddda2b([""Stem""]):::none
    xd03d7c7dd2ddda2b([""Stem""]):::none --- xeb2d7cac8a1ce544>""Function""]:::none
    xeb2d7cac8a1ce544>""Function""]:::none --- xbecb13963f49e50b{{""Object""}}:::none
  end
  subgraph Graph
    direction LR
    x9252423d64d713bd>"genColor"]:::uptodate --> xe286972e47efcd5a>"setStripColor"]:::uptodate
    x9252423d64d713bd>"genColor"]:::uptodate --> xb8b267aae822a938>"vizDot"]:::uptodate
    x9252423d64d713bd>"genColor"]:::uptodate --> xd24d44e5b9dcbfab>"setRefTable"]:::uptodate
    x9252423d64d713bd>"genColor"]:::uptodate --> xa4ed09271e4b7e0c>"vizAutocor"]:::uptodate
    x9252423d64d713bd>"genColor"]:::uptodate --> x517170a0862823a9>"vizDotAug"]:::uptodate
    xbd46e7a6b2bc9551>"setDot"]:::uptodate --> xb8b267aae822a938>"vizDot"]:::uptodate
    xbd46e7a6b2bc9551>"setDot"]:::uptodate --> x517170a0862823a9>"vizDotAug"]:::uptodate
    xb5013b1c32262a9b>"setFacet"]:::uptodate --> xb8b267aae822a938>"vizDot"]:::uptodate
    xb5013b1c32262a9b>"setFacet"]:::uptodate --> x517170a0862823a9>"vizDotAug"]:::uptodate
    xe286972e47efcd5a>"setStripColor"]:::uptodate --> xb8b267aae822a938>"vizDot"]:::uptodate
    xe286972e47efcd5a>"setStripColor"]:::uptodate --> xa4ed09271e4b7e0c>"vizAutocor"]:::uptodate
    xe286972e47efcd5a>"setStripColor"]:::uptodate --> x517170a0862823a9>"vizDotAug"]:::uptodate
    xd24d44e5b9dcbfab>"setRefTable"]:::uptodate --> xe286972e47efcd5a>"setStripColor"]:::uptodate
    x5cd0059b4a190559>"splitTs"]:::uptodate --> xacaa2b0b099a3bef>"compareModel"]:::uptodate
    x2cba9b87114d8cdd>"genModelForm"]:::uptodate --> xacaa2b0b099a3bef>"compareModel"]:::uptodate
    xa644072f7a1b7229>"castModel"]:::uptodate --> xee4f8d86dc7f5415(["mod_cast"]):::uptodate
    xe177f97af32c2a84(["mod"]):::uptodate --> xee4f8d86dc7f5415(["mod_cast"]):::uptodate
    x41ba333bb4a8eac2>"getDiff"]:::uptodate --> x97481d93fc034ba1(["res_diff"]):::uptodate
    xace8ed3b55f17498(["sub_tbl"]):::uptodate --> x97481d93fc034ba1(["res_diff"]):::uptodate
    x35b4e9316d9a0feb(["best_fit"]):::uptodate --> x03f2053ede238c51(["best_cast"]):::uptodate
    xd5d9f89b36ce2fd3(["mod_cast_its"]):::uptodate --> x03f2053ede238c51(["best_cast"]):::uptodate
    x16fdcdd8569d4e24>"selectForecast"]:::uptodate --> x03f2053ede238c51(["best_cast"]):::uptodate
    xc488683e3df4e665(["ts_aug"]):::uptodate --> xa96ae55b1b18d8fc(["plt_dot_aug"]):::uptodate
    x517170a0862823a9>"vizDotAug"]:::uptodate --> xa96ae55b1b18d8fc(["plt_dot_aug"]):::uptodate
    x1a0b2ed0fd224eb0>"augmentModel"]:::uptodate --> xc488683e3df4e665(["ts_aug"]):::uptodate
    x03f2053ede238c51(["best_cast"]):::uptodate --> xc488683e3df4e665(["ts_aug"]):::uptodate
    x310fe0d702765c29(["mod_its"]):::uptodate --> xc488683e3df4e665(["ts_aug"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> xc488683e3df4e665(["ts_aug"]):::uptodate
    xacaa2b0b099a3bef>"compareModel"]:::uptodate --> x310fe0d702765c29(["mod_its"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> x310fe0d702765c29(["mod_its"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> x674283d12376b53b(["plt_pacf"]):::uptodate
    xa4ed09271e4b7e0c>"vizAutocor"]:::uptodate --> x674283d12376b53b(["plt_pacf"]):::uptodate
    x1f6d76ea8940cecf{{"raws"}}:::uptodate --> xb82194ad1d3356df(["file_ts"]):::uptodate
    x1f6d76ea8940cecf{{"raws"}}:::uptodate --> x6fba182254a20175(["file_tbl"]):::uptodate
    x0e4824291d40911d(["mod_eval"]):::uptodate --> x35b4e9316d9a0feb(["best_fit"]):::uptodate
    x1c4ab9118e3ea071>"selectModel"]:::uptodate --> x35b4e9316d9a0feb(["best_fit"]):::uptodate
    x7b6a434a2a79ead8>"evalModel"]:::uptodate --> x0e4824291d40911d(["mod_eval"]):::uptodate
    xee4f8d86dc7f5415(["mod_cast"]):::uptodate --> x0e4824291d40911d(["mod_eval"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> x0e4824291d40911d(["mod_eval"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> xc590316f7a9c8a5d(["plt_acf"]):::uptodate
    xa4ed09271e4b7e0c>"vizAutocor"]:::uptodate --> xc590316f7a9c8a5d(["plt_acf"]):::uptodate
    x6fba182254a20175(["file_tbl"]):::uptodate --> xb24e8ba9befc2f2c(["tbl"]):::uptodate
    x18b26034ab3a95e2>"readData"]:::uptodate --> xb24e8ba9befc2f2c(["tbl"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> x15da876e665e6188(["plt_dot"]):::uptodate
    xb8b267aae822a938>"vizDot"]:::uptodate --> x15da876e665e6188(["plt_dot"]):::uptodate
    xa644072f7a1b7229>"castModel"]:::uptodate --> xd5d9f89b36ce2fd3(["mod_cast_its"]):::uptodate
    x310fe0d702765c29(["mod_its"]):::uptodate --> xd5d9f89b36ce2fd3(["mod_cast_its"]):::uptodate
    xacaa2b0b099a3bef>"compareModel"]:::uptodate --> xe177f97af32c2a84(["mod"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> xe177f97af32c2a84(["mod"]):::uptodate
    xe777d5278e8501a6>"checkTrend"]:::uptodate --> xbdb43b025d9b1b25(["res_trend"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> xbdb43b025d9b1b25(["res_trend"]):::uptodate
    xd7e58f14e419de9c>"subsetData"]:::uptodate --> xace8ed3b55f17498(["sub_tbl"]):::uptodate
    xb24e8ba9befc2f2c(["tbl"]):::uptodate --> xace8ed3b55f17498(["sub_tbl"]):::uptodate
    x69167921da2c5a4c(["ts"]):::uptodate --> xace8ed3b55f17498(["sub_tbl"]):::uptodate
    xb82194ad1d3356df(["file_ts"]):::uptodate --> x69167921da2c5a4c(["ts"]):::uptodate
    x18b26034ab3a95e2>"readData"]:::uptodate --> x69167921da2c5a4c(["ts"]):::uptodate
    xc11069275cfeb620(["readme"]):::dispatched --> xc11069275cfeb620(["readme"]):::dispatched
    x4d3ec24f81457d7f{{"seed"}}:::uptodate --> x4d3ec24f81457d7f{{"seed"}}:::uptodate
    x2f12837377761a1b{{"pkgs"}}:::uptodate --> x2f12837377761a1b{{"pkgs"}}:::uptodate
    x07bf962581a33ad1{{"funs"}}:::uptodate --> x07bf962581a33ad1{{"funs"}}:::uptodate
    x026e3308cd8be8b9{{"pkgs_load"}}:::uptodate --> x026e3308cd8be8b9{{"pkgs_load"}}:::uptodate
    x3eac3c5af5491b67>"lsData"]:::uptodate --> x3eac3c5af5491b67>"lsData"]:::uptodate
  end
  classDef uptodate stroke:#000000,color:#ffffff,fill:#354823;
  classDef dispatched stroke:#000000,color:#000000,fill:#DC863B;
  classDef none stroke:#000000,color:#000000,fill:#94a4ac;
  linkStyle 0 stroke-width:0px;
  linkStyle 1 stroke-width:0px;
  linkStyle 2 stroke-width:0px;
  linkStyle 3 stroke-width:0px;
  linkStyle 60 stroke-width:0px;
  linkStyle 61 stroke-width:0px;
  linkStyle 62 stroke-width:0px;
  linkStyle 63 stroke-width:0px;
  linkStyle 64 stroke-width:0px;
  linkStyle 65 stroke-width:0px;
```
