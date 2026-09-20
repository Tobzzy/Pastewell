const siteConfig = {
  repository: "Tobzzy/Pastewell",
  appStoreUrl: "",
  sponsorUrl: ""
};

document.getElementById("year").textContent = new Date().getFullYear();

const header = document.querySelector(".site-header");
const updateHeader = () => header.classList.toggle("scrolled", window.scrollY > 8);
updateHeader();
window.addEventListener("scroll", updateHeader, { passive: true });

const revealObserver = new IntersectionObserver(
  entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.12 }
);

document.querySelectorAll(".reveal").forEach(element => revealObserver.observe(element));

if (siteConfig.appStoreUrl) {
  document.querySelectorAll("[data-app-store-link]").forEach(link => {
    link.href = siteConfig.appStoreUrl;
    link.hidden = false;
  });
}

if (siteConfig.sponsorUrl) {
  document.querySelectorAll("[data-sponsor-link]").forEach(link => {
    link.href = siteConfig.sponsorUrl;
    link.hidden = false;
  });
}

async function connectLatestRelease() {
  const fallback = `https://github.com/${siteConfig.repository}/releases/latest`;

  try {
    const response = await fetch(`https://api.github.com/repos/${siteConfig.repository}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" }
    });
    if (!response.ok) throw new Error(`GitHub returned ${response.status}`);

    const release = await response.json();
    const archive = release.assets.find(asset =>
      asset.name.endsWith("macOS-universal.zip") && !asset.name.endsWith(".sha256")
    );
    const destination = archive?.browser_download_url || release.html_url || fallback;

    document.querySelectorAll(".release-link").forEach(link => {
      link.href = destination;
    });

    const version = document.getElementById("release-version");
    version.textContent = `${release.tag_name || "Latest"} · Free download`;
  } catch (error) {
    document.querySelectorAll(".release-link").forEach(link => {
      link.href = fallback;
    });
  }
}

connectLatestRelease();
