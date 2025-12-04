allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- ĐOẠN CODE FIX LỖI NAMESPACE (ĐÃ SỬA LỖI AFTEREVALUATE) ---
subprojects {
    // Định nghĩa logic sửa lỗi Namespace
    val fixNamespace = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                
                val currentNamespace = getNamespace.invoke(android)
                
                if (currentNamespace == null) {
                    var newNamespace = group.toString()
                    // Tạo tên namespace an toàn
                    if (newNamespace == "null" || newNamespace.isEmpty()) {
                        val safeName = name.replace("-", "_")
                        newNamespace = "com.example.$safeName"
                    }
                    println("🔧 Auto-fixing Namespace for: $name -> $newNamespace")
                    setNamespace.invoke(android, newNamespace)
                }
            } catch (e: Exception) {
                // Bỏ qua lỗi
            }
        }
    }

    // KIỂM TRA TRẠNG THÁI: Tránh lỗi "Project already evaluated"
    if (state.executed) {
        // Nếu dự án đã load xong rồi -> Chạy fix luôn
        fixNamespace()
    } else {
        // Nếu chưa xong -> Đợi load xong mới chạy
        afterEvaluate {
            fixNamespace()
        }
    }
}